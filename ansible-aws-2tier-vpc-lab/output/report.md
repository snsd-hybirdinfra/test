# Ansible AWS 2-Tier VPC Automation Lab Report

## 1. Lab Summary

This report summarizes the AWS 2-tier web infrastructure provisioned by Ansible.

- Project: ansible-vpc-lab
- Owner: jjh
- ManagedBy: ansible
- Region: ap-northeast-2
- Generated At: 2026-06-05T02:24:24Z

---

## 2. Network Resources

| Resource | Value |
|---|---|
| VPC ID | vpc-06c9a1e215df45e5d |
| Public Subnet 1 | subnet-0be42129816609516 |
| Public Subnet 2 | subnet-0eee36379115bf199 |
| Private Subnet 1 | subnet-0bc4ba91f5ab40010 |
| Private Subnet 2 | subnet-06e7657667b7e2d01 |
| Internet Gateway | igw-0fde1a515a1e024a1 |
| NAT Gateway | nat-0aef8f4d8d3e32bf2 |
| Public Route Table | rtb-07f9c02b0d54acdaf |
| Private Route Table | rtb-02577befc322ae168 |

---

## 3. Security Groups

| Security Group | ID |
|---|---|
| ALB SG | sg-012159a397e6ada61 |
| Bastion SG | sg-0a16446403fae8a15 |
| Web SG | sg-0e03a2ad076d7b02d |

---

## 4. Compute Resources

| Resource | Value |
|---|---|
| Key Name | ansible-jjh-key |
| AMI ID | ami-0ffa3ea08830db2a0 |
| Bastion Instance ID | i-08fad194a7292953b |
| Bastion Public IP | 43.201.252.25 |
| Bastion Private IP | 10.21.1.149 |
| Web 1 Instance ID | i-0b7a6adf7ea9da115 |
| Web 1 Private IP | 10.21.11.146 |
| Web 2 Instance ID | i-0a784ecd6e658daa9 |
| Web 2 Private IP | 10.21.12.122 |

---

## 5. Load Balancer

| Resource | Value |
|---|---|
| ALB Name | ansible-jjh-alb |
| ALB DNS | ansible-jjh-alb-757708604.ap-northeast-2.elb.amazonaws.com |
| Target Group Name | ansible-jjh-tg |
| Target Group ARN | arn:aws:elasticloadbalancing:ap-northeast-2:233727959884:targetgroup/ansible-jjh-tg/974a9ee5e965270c |
| Web 1 Target | i-0b7a6adf7ea9da115 |
| Web 2 Target | i-0a784ecd6e658daa9 |

---

## 6. Validation Result

| Check | Result |
|---|---|
| ALB HTTP Status | 200 |
| ALB Response Body | Hello from ansible-jjh-web-1  |
| Bastion Instance | i-08fad194a7292953b |
| Web 1 Instance | i-0b7a6adf7ea9da115 |
| Web 2 Instance | i-0a784ecd6e658daa9 |

---

## 7. Architecture Notes

This lab uses a cost-optimized NAT Gateway design.

- One NAT Gateway is deployed in Public Subnet 1.
- Both private subnets use the same NAT Gateway for outbound internet access.
- A production-grade design would typically deploy one NAT Gateway per Availability Zone.

Private web servers are not directly exposed to the internet.

- HTTP traffic enters through the ALB.
- SSH access to private web servers is expected to pass through the Bastion host.
- Web security group allows HTTP only from the ALB security group.

---

## 8. Cleanup

To delete all lab resources:

    ./99_delete_all.sh

---

## 9. Future Extension

Planned extension candidates:

- Domain connection using gg-snsdinfra.cloud
- Gabia DNS record configuration
- ACM DNS validation
- ALB HTTPS listener
- HTTP to HTTPS redirect
- Auto Scaling Group
- CloudWatch monitoring and alarms
