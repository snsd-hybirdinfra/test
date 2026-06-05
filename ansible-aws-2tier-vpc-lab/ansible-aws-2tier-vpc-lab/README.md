# Ansible AWS 2-Tier VPC Automation Lab

## 1. Overview

This lab builds a cost-optimized 2-tier AWS web infrastructure using Ansible.

The automation provisions and validates:

- VPC
- Public and private subnets across two Availability Zones
- Internet Gateway
- NAT Gateway
- Public and private route tables
- Security groups
- Bastion EC2 instance
- Two private web EC2 instances
- Application Load Balancer
- Target Group
- HTTP listener
- Infrastructure validation
- Dynamic Ansible inventory generation
- Private web server operational check
- Cleanup automation

---

## 2. Architecture

    Internet
       |
       v
    Application Load Balancer
       |
       v
    Private Web EC2 instances

    Management Host
       |
       v
    Bastion EC2
       |
       v
    Private Web EC2 instances

    VPC: 10.21.0.0/16

    Public Subnet 1  : 10.21.1.0/24   ap-northeast-2a
    Public Subnet 2  : 10.21.2.0/24   ap-northeast-2c

    Private Subnet 1 : 10.21.11.0/24  ap-northeast-2a
    Private Subnet 2 : 10.21.12.0/24  ap-northeast-2c

---

## 3. Resource Naming

All lab resources use the following naming convention:

    ansible-jjh-*

Common tags:

    Project: ansible-vpc-lab
    Owner: jjh
    ManagedBy: ansible

---

## 4. File Structure

    /home/user1/lab/aws/
    ├── 00_syntax_check.sh
    ├── 00_run_all.sh
    ├── 01_create_base_network.yml
    ├── 02_create_security_groups.yml
    ├── 03_create_compute.yml
    ├── 04_create_alb.yml
    ├── 05_validate.yml
    ├── 06_generate_inventory.yml
    ├── 07_check_web_servers.yml
    ├── 08_generate_report.yml
    ├── 99_delete_all.sh
    ├── inventory.ini
    ├── output/
    │   ├── base_network.yml
    │   ├── security_groups.yml
    │   ├── compute.yml
    │   ├── alb.yml
    │   └── validation.yml
    └── README.md

---

## 5. Execution Order

### Step 0. Syntax Check

    ./00_syntax_check.sh

### Step 1. Create Base Network

    ansible-playbook 01_create_base_network.yml

Creates:

- VPC
- Public subnets
- Private subnets
- Internet Gateway
- Public route table
- NAT Gateway
- Private route table

Output:

    cat output/base_network.yml

### Step 2. Create Security Groups

    ansible-playbook 02_create_security_groups.yml

Creates:

- ALB security group
- Bastion security group
- Web security group

Output:

    cat output/security_groups.yml

### Step 3. Create Compute Resources

    ansible-playbook 03_create_compute.yml

Creates:

- SSH key pair
- Bastion EC2 instance
- Web EC2 instance 1
- Web EC2 instance 2

Output:

    cat output/compute.yml

### Step 4. Create ALB

    ansible-playbook 04_create_alb.yml

Creates:

- Target Group
- Application Load Balancer
- HTTP Listener

Output:

    cat output/alb.yml

### Step 5. Validate Infrastructure

    ansible-playbook 05_validate.yml

Validates:

- EC2 instance state
- Target Group health
- ALB HTTP response

Output:

    cat output/validation.yml

### Step 6. Generate Dynamic Inventory

    ansible-playbook 06_generate_inventory.yml

Creates:

- inventory.ini

Output:

    cat inventory.ini

### Step 7. Check Private Web Servers

    ansible-playbook -i inventory.ini 07_check_web_servers.yml
    ├── 08_generate_report.yml

Validates through Bastion:

- Web SSH access
- Hostname
- httpd service status
- Local HTTP response

---

## 6. One-Shot Execution

Run the full provisioning workflow:

    ./00_run_all.sh

Recommended order:

    ./00_syntax_check.sh
    ./00_run_all.sh
    ansible-playbook -i inventory.ini 07_check_web_servers.yml
    ├── 08_generate_report.yml

---

## 7. Security Group Design

### ALB Security Group

    Inbound:
    - TCP 80 from 0.0.0.0/0

    Outbound:
    - All traffic

### Bastion Security Group

    Inbound:
    - TCP 22 from 0.0.0.0/0

    Outbound:
    - All traffic

For production, SSH should be restricted to a trusted source IP.

### Web Security Group

    Inbound:
    - TCP 22 from Bastion SG
    - TCP 80 from ALB SG

    Outbound:
    - All traffic

The private web servers are not directly exposed to the internet.

---

## 8. Cost-Optimized Design Note

This lab uses one NAT Gateway in Public Subnet 1.

    Private Subnet 1 -> NAT Gateway
    Private Subnet 2 -> NAT Gateway

For production-grade high availability, one NAT Gateway per Availability Zone is recommended.

    Private Subnet 1 -> NAT Gateway in AZ 1
    Private Subnet 2 -> NAT Gateway in AZ 2

The current design intentionally uses one NAT Gateway to reduce lab cost.

---

## 9. Validation Commands

Check VPC:

    aws ec2 describe-vpcs \
      --region ap-northeast-2 \
      --filters "Name=tag:Project,Values=ansible-vpc-lab" "Name=tag:Owner,Values=jjh" \
      --output table

Check EC2:

    aws ec2 describe-instances \
      --region ap-northeast-2 \
      --filters "Name=tag:Project,Values=ansible-vpc-lab" "Name=tag:Owner,Values=jjh" \
      --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress,Name:Tags[?Key==`Name`]|[0].Value}' \
      --output table

Check Target Health:

    TG_ARN=$(grep arn output/alb.yml | awk '{print $2}' | tr -d '"')

    aws elbv2 describe-target-health \
      --target-group-arn $TG_ARN \
      --region ap-northeast-2 \
      --query 'TargetHealthDescriptions[].{Target:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason}' \
      --output table

Check ALB response:

    ALB_DNS=$(grep dns_name output/alb.yml | awk '{print $2}' | tr -d '"')

    curl http://$ALB_DNS

Expected response:

    Hello from ansible-jjh-web-1

or

    Hello from ansible-jjh-web-2

Check Web servers through Bastion:

    ansible -i inventory.ini web -m ping

    ansible-playbook -i inventory.ini 07_check_web_servers.yml
    ├── 08_generate_report.yml

---

## 10. Cleanup

Delete all lab resources:

    ./99_delete_all.sh

Confirm deletion:

    aws ec2 describe-vpcs \
      --region ap-northeast-2 \
      --filters "Name=tag:Project,Values=ansible-vpc-lab" "Name=tag:Owner,Values=jjh" \
      --output table

---

## 11. Future Extension

Possible next improvements:

- Domain connection using gg-snsdinfra.cloud
- ACM certificate validation
- HTTPS listener on ALB
- HTTP to HTTPS redirect
- Route 53 or external DNS integration
- Auto Scaling Group
- CloudWatch monitoring and alarms

---

## 12. Summary

This lab demonstrates Ansible-based AWS infrastructure automation for a 2-tier web architecture.

It covers:

- Network provisioning
- Security group design
- EC2 provisioning
- ALB integration
- Output variable handoff between playbooks
- Dynamic inventory generation
- Bastion-based private server operation
- Infrastructure validation
- Cleanup automation

---

## 13. Final Report Generation

Generate a final Markdown report from output variables:

    ansible-playbook 08_generate_report.yml

Output:

    cat output/report.md

The report includes:

- Network resource summary
- Security group summary
- Compute resource summary
- ALB and Target Group summary
- Validation result
- Cleanup command
- Future extension candidates


---

## 14. Sanitized Example Output Generation

Generated output files may contain real AWS resource IDs, public IPs, private IPs, ALB DNS names, and target group ARNs.

For GitHub upload, sanitized example output files can be generated with:

    ansible-playbook 10_generate_examples.yml

This creates example files under:

    output/example/

Generated example files:

    output/example/base_network.example.yml
    output/example/security_groups.example.yml
    output/example/compute.example.yml
    output/example/alb.example.yml
    output/example/validation.example.yml

These files show the expected output structure without exposing real AWS resource values.


---

## 15. Cleanup Behavior

The cleanup script removes AWS resources created by this lab.

Run:

    ./99_delete_all.sh

Cleanup order:

    1. Delete ALB listeners and load balancers
    2. Wait for ALB deletion
    3. Delete target groups
    4. Terminate EC2 instances
    5. Wait for EC2 termination
    6. Delete NAT Gateways
    7. Wait for NAT Gateway deletion
    8. Release Elastic IP allocations
    9. Delete non-main route tables
    10. Detach and delete Internet Gateways
    11. Delete subnets
    12. Revoke and delete custom Security Groups
    13. Delete VPC
    14. Delete AWS key pair
    15. Delete local generated key and inventory files

AWS resources such as NAT Gateways, Elastic Network Interfaces, ALBs, and EC2 instances are deleted asynchronously.

Because of this, the cleanup script is designed to be safely re-runnable.

If some resources remain after the first execution, wait briefly and run:

    ./99_delete_all.sh

again.

This behavior is expected when AWS is still finalizing dependent resource deletion.

