#!/bin/bash
set -e

REGION="ap-northeast-2"
PROJECT="ansible-vpc-lab"
OWNER="jjh"
KEY_NAME="ansible-jjh-key"

echo "======================================"
echo "Delete AWS resources for $OWNER / $PROJECT"
echo "Region: $REGION"
echo "======================================"

echo "[1] Delete ALB"

ALB_ARNS=$(aws elbv2 describe-load-balancers \
  --region "$REGION" \
  --query "LoadBalancers[?contains(LoadBalancerName, 'ansible-jjh-alb')].LoadBalancerArn" \
  --output text 2>/dev/null || true)

for ALB_ARN in $ALB_ARNS; do
  echo "Deleting ALB: $ALB_ARN"

  aws elbv2 delete-load-balancer \
    --load-balancer-arn "$ALB_ARN" \
    --region "$REGION" 2>/dev/null || true

  aws elbv2 wait load-balancers-deleted \
    --load-balancer-arns "$ALB_ARN" \
    --region "$REGION" 2>/dev/null || true
done

echo "[2] Delete Target Groups"

TG_ARNS=$(aws elbv2 describe-target-groups \
  --region "$REGION" \
  --query "TargetGroups[?contains(TargetGroupName, 'ansible-jjh-tg')].TargetGroupArn" \
  --output text 2>/dev/null || true)

for TG_ARN in $TG_ARNS; do
  echo "Deleting Target Group: $TG_ARN"

  aws elbv2 delete-target-group \
    --target-group-arn "$TG_ARN" \
    --region "$REGION" 2>/dev/null || true
done

echo "[3] Terminate EC2 instances"

INSTANCE_IDS=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters \
    "Name=tag:Project,Values=$PROJECT" \
    "Name=tag:Owner,Values=$OWNER" \
    "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text 2>/dev/null || true)

if [ -n "$INSTANCE_IDS" ]; then
  echo "Terminating instances: $INSTANCE_IDS"

  aws ec2 terminate-instances \
    --instance-ids $INSTANCE_IDS \
    --region "$REGION" 2>/dev/null || true

  aws ec2 wait instance-terminated \
    --instance-ids $INSTANCE_IDS \
    --region "$REGION" 2>/dev/null || true
fi

echo "[4] Find VPC"

VPC_IDS=$(aws ec2 describe-vpcs \
  --region "$REGION" \
  --filters \
    "Name=tag:Project,Values=$PROJECT" \
    "Name=tag:Owner,Values=$OWNER" \
  --query 'Vpcs[].VpcId' \
  --output text 2>/dev/null || true)

for VPC_ID in $VPC_IDS; do
  echo "Processing VPC: $VPC_ID"

  echo "[5] Delete NAT Gateways"

  NAT_GW_IDS=$(aws ec2 describe-nat-gateways \
    --region "$REGION" \
    --filter "Name=vpc-id,Values=$VPC_ID" \
    --query 'NatGateways[?State!=`deleted`].NatGatewayId' \
    --output text 2>/dev/null || true)

  for NAT_GW_ID in $NAT_GW_IDS; do
    EIP_ALLOC_ID=$(aws ec2 describe-nat-gateways \
      --nat-gateway-ids "$NAT_GW_ID" \
      --region "$REGION" \
      --query 'NatGateways[0].NatGatewayAddresses[0].AllocationId' \
      --output text 2>/dev/null || echo "None")

    echo "Deleting NAT Gateway: $NAT_GW_ID"

    aws ec2 delete-nat-gateway \
      --nat-gateway-id "$NAT_GW_ID" \
      --region "$REGION" 2>/dev/null || true

    aws ec2 wait nat-gateway-deleted \
      --nat-gateway-ids "$NAT_GW_ID" \
      --region "$REGION" 2>/dev/null || true

    if [ "$EIP_ALLOC_ID" != "None" ] && [ "$EIP_ALLOC_ID" != "null" ]; then
      echo "Releasing EIP: $EIP_ALLOC_ID"

      aws ec2 release-address \
        --allocation-id "$EIP_ALLOC_ID" \
        --region "$REGION" 2>/dev/null || true
    fi
  done

  echo "[6] Delete non-main Route Tables"

  RTB_IDS=$(aws ec2 describe-route-tables \
    --region "$REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' \
    --output text 2>/dev/null || true)

  for RTB_ID in $RTB_IDS; do
    ASSOC_IDS=$(aws ec2 describe-route-tables \
      --route-table-ids "$RTB_ID" \
      --region "$REGION" \
      --query 'RouteTables[0].Associations[?Main==`false`].RouteTableAssociationId' \
      --output text 2>/dev/null || true)

    for ASSOC_ID in $ASSOC_IDS; do
      echo "Disassociating route table association: $ASSOC_ID"

      aws ec2 disassociate-route-table \
        --association-id "$ASSOC_ID" \
        --region "$REGION" 2>/dev/null || true
    done

    echo "Deleting Route Table: $RTB_ID"

    aws ec2 delete-route-table \
      --route-table-id "$RTB_ID" \
      --region "$REGION" 2>/dev/null || true
  done

  echo "[7] Detach and delete Internet Gateways"

  IGW_IDS=$(aws ec2 describe-internet-gateways \
    --region "$REGION" \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --query 'InternetGateways[].InternetGatewayId' \
    --output text 2>/dev/null || true)

  for IGW_ID in $IGW_IDS; do
    echo "Deleting IGW: $IGW_ID"

    aws ec2 detach-internet-gateway \
      --internet-gateway-id "$IGW_ID" \
      --vpc-id "$VPC_ID" \
      --region "$REGION" 2>/dev/null || true

    aws ec2 delete-internet-gateway \
      --internet-gateway-id "$IGW_ID" \
      --region "$REGION" 2>/dev/null || true
  done

  echo "[8] Delete Subnets"

  SUBNET_IDS=$(aws ec2 describe-subnets \
    --region "$REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[].SubnetId' \
    --output text 2>/dev/null || true)

  for SUBNET_ID in $SUBNET_IDS; do
    echo "Deleting Subnet: $SUBNET_ID"

    aws ec2 delete-subnet \
      --subnet-id "$SUBNET_ID" \
      --region "$REGION" 2>/dev/null || true
  done

  echo "[9] Delete Security Groups except default"

  SG_IDS=$(aws ec2 describe-security-groups \
    --region "$REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
    --output text 2>/dev/null || true)

  for SG_ID in $SG_IDS; do
    echo "Deleting Security Group: $SG_ID"

    aws ec2 delete-security-group \
      --group-id "$SG_ID" \
      --region "$REGION" 2>/dev/null || true
  done

  echo "[10] Delete VPC: $VPC_ID"

  aws ec2 delete-vpc \
    --vpc-id "$VPC_ID" \
    --region "$REGION"
done

echo "[11] Delete Key Pair"

aws ec2 delete-key-pair \
  --key-name "$KEY_NAME" \
  --region "$REGION" 2>/dev/null || true

echo "[12] Delete local key files"

rm -f /home/user1/lab/aws/ansible-jjh-key
rm -f /home/user1/lab/aws/ansible-jjh-key.pub

echo "DONE: all ansible-jjh lab resources deleted."
