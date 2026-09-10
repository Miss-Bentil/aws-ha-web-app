# AWS Highly Available Web Application

A highly available AWS web application infrastructure project built with **Terraform**.

This project demonstrates practical cloud engineering concepts including VPC networking, public/private subnet architecture, EC2 Auto Scaling, Application Load Balancing, Amazon RDS PostgreSQL, IAM, CloudWatch monitoring, security groups, NAT Gateways, and remote Terraform state.

> **Project status:** Infrastructure has been fully defined, formatted, validated, and reviewed with `terraform plan`. The infrastructure has **not yet been deployed to AWS** to avoid unnecessary development costs.

---

## Architecture

```text
                         INTERNET USERS
                               |
                               v
                    +----------------------+
                    | Application Load     |
                    |      Balancer        |
                    |    Public Subnets    |
                    +----------+-----------+
                               |
                    +----------+----------+
                    |                     |
                    v                     v
             +------------+        +------------+
             | EC2 Server |        | EC2 Server |
             |     #1     |        |     #2     |
             | Private AZ |        | Private AZ |
             +------+-----+        +------+-----+
                    |                     |
                    +----------+----------+
                               |
                               v
                     +-------------------+
                     | Amazon RDS        |
                     | PostgreSQL        |
                     | Private Subnets   |
                     +-------------------+

                    Provisioned with Terraform
```

---

## AWS Services

| Service                   | Purpose                                       |
| ------------------------- | --------------------------------------------- |
| Amazon VPC                | Isolated network environment                  |
| EC2                       | Application servers                           |
| Auto Scaling              | Maintains application capacity                |
| Application Load Balancer | Distributes incoming traffic                  |
| RDS PostgreSQL            | Managed relational database                   |
| IAM                       | Identity and access management                |
| Systems Manager           | Secure EC2 administration                     |
| CloudWatch                | Infrastructure monitoring                     |
| SNS                       | Alarm notifications                           |
| S3                        | Remote Terraform state                        |
| NAT Gateway               | Outbound internet access from private subnets |
| Internet Gateway          | Internet connectivity for the VPC             |

---

## Network Architecture

The application uses a `10.0.0.0/16` VPC distributed across two Availability Zones in `eu-west-2`.

### Availability Zone A

```text
Public Subnet
10.0.1.0/24

Private Subnet
10.0.11.0/24
```

### Availability Zone B

```text
Public Subnet
10.0.2.0/24

Private Subnet
10.0.12.0/24
```

### Network layout

```text
VPC: 10.0.0.0/16

                    VPC
                     |
          +----------+----------+
          |                     |
        AZ-A                  AZ-B
          |                     |
    +-----+-----+         +-----+-----+
    |           |         |           |
 Public      Private    Public      Private
10.0.1/24   10.0.11/24 10.0.2/24  10.0.12/24
    |           |         |           |
    |           |         |           |
   ALB         EC2       ALB         EC2
    |                       |
  NAT GW                  NAT GW
```

Public subnets route internet traffic through the Internet Gateway.

Private subnets use NAT Gateways for outbound internet access without exposing the EC2 instances directly to the internet.

---

## High Availability

The infrastructure is designed to reduce single points of failure.

### Application layer

The Auto Scaling Group spans two Availability Zones and is configured with:

* Minimum instances: `2`
* Desired instances: `2`
* Maximum instances: `4`

If an application instance becomes unhealthy, the Auto Scaling Group can replace it.

The Application Load Balancer distributes traffic across healthy instances.

### Network layer

The project uses:

* Two Availability Zones
* Two public subnets
* Two private subnets
* One NAT Gateway per Availability Zone
* An internet-facing Application Load Balancer across both public subnets

Using separate NAT Gateways improves Availability Zone independence, although it increases AWS cost.

### Database layer

Amazon RDS PostgreSQL is deployed in private subnets with public access disabled.

For this development configuration, Multi-AZ is disabled to keep costs lower.

---

## Security Design

Security is implemented using separate Security Groups for each infrastructure tier.

```text
Internet
   |
   | HTTP / HTTPS
   v
ALB Security Group
   |
   | HTTP :80
   v
EC2 Security Group
   |
   | PostgreSQL :5432
   v
RDS Security Group
```

### ALB

The ALB accepts:

* HTTP on port 80
* HTTPS on port 443

from the internet.

### EC2

EC2 instances accept HTTP traffic only from the ALB Security Group.

They are not directly exposed to the internet.

### RDS

RDS accepts PostgreSQL traffic only from the EC2 Security Group.

This prevents direct public access to the database.

---

## IAM and Systems Manager

EC2 instances use an IAM role with:

* `AmazonSSMManagedInstanceCore`
* `CloudWatchAgentServerPolicy`

Systems Manager allows administrative access to EC2 without requiring SSH access from the internet.

This reduces the exposed attack surface and removes the need to distribute SSH private keys.

---

## Compute

The application servers use:

* Amazon Linux 2023
* `t3.micro`
* EC2 Launch Template
* Auto Scaling Group
* Nginx

The Amazon Linux AMI is retrieved through the AWS Systems Manager public parameter rather than hard-coded.

The EC2 user-data script installs Nginx and creates a simple test web page.

---

## Load Balancing

The Application Load Balancer:

* Is internet-facing
* Runs across both public subnets
* Listens on HTTP port 80
* Uses an EC2 target group
* Performs HTTP health checks
* Routes traffic only to healthy targets

HTTPS can be added with AWS Certificate Manager and a domain name.

---

## Database

Amazon RDS PostgreSQL is configured with:

* PostgreSQL 17
* `db.t3.micro`
* 20 GB GP3 storage
* Private subnets
* Public access disabled
* Seven-day automated backup retention
* AWS-managed master password
* Single-AZ deployment for the development environment

The database password is managed by AWS rather than being hard-coded in Terraform configuration.

---

## Monitoring

CloudWatch monitors EC2 Auto Scaling Group CPU utilization.

The project includes a CPU alarm configured to trigger when average CPU utilization remains above **70% for two consecutive five-minute periods**.

An SNS topic is used as the notification destination.

Future monitoring improvements could include:

* ALB unhealthy target alarms
* ALB 5xx alarms
* RDS CPU alarms
* RDS storage alarms
* CloudWatch dashboards
* Application-level health metrics

---

## Terraform Structure

```text
aws-ha-web-app/
│
├── README.md
├── .gitignore
│
├── bootstrap/
│   └── remote-state/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── environments/
│   └── dev/
│       ├── backend.tf
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── provider.tf
│       └── terraform.tfvars
│
├── modules/
│   ├── networking/
│   ├── security/
│   ├── compute/
│   ├── load_balancer/
│   ├── database/
│   └── monitoring/
│
└── docs/
    ├── architecture.md
    ├── deployment.md
    └── screenshots/
```

The project uses reusable Terraform modules to separate infrastructure responsibilities.

---

## Remote Terraform State

The development environment uses an encrypted Amazon S3 backend for Terraform state.

```text
S3
└── aws-ha-web-app/dev/terraform.tfstate
```

The remote state configuration includes:

* S3 remote state
* Server-side encryption
* S3 versioning
* Public access blocking
* Terraform state locking using the S3 lockfile mechanism

The remote-state bucket is created separately through the bootstrap configuration.

---

## Validation

The Terraform configuration is checked using:

```powershell
terraform fmt
terraform validate
terraform plan
```

The current infrastructure plan is:

```text
Plan: 34 to add, 0 to change, 0 to destroy.
```

`terraform plan` does **not** create AWS resources.

---

## Cost Considerations

This project is intentionally designed to allow the architecture to be reviewed without deploying the infrastructure.

Resources that can generate AWS charges include:

* NAT Gateways
* EC2 instances
* Application Load Balancer
* RDS
* CloudWatch
* SNS

Development settings use smaller instance classes and a single-AZ database configuration where appropriate.

> **Important:** Do not run `terraform apply` unless you are ready to incur AWS charges.

---

## Planned Deployment Workflow

```text
Terraform Configuration
          |
          v
terraform fmt
          |
          v
terraform validate
          |
          v
terraform plan
          |
          v
terraform apply
          |
          v
Validate AWS Resources
          |
          v
Test High Availability
          |
          v
terraform destroy
```

Deployment and testing instructions are available in [`docs/deployment.md`](docs/deployment.md).

---

## High Availability Test Plan

When the infrastructure is deployed, the following tests can be performed:

1. Confirm two EC2 instances are running.
2. Confirm the instances are distributed across different Availability Zones.
3. Confirm both instances are healthy ALB targets.
4. Access the application through the ALB DNS name.
5. Terminate one application instance.
6. Confirm the application remains available.
7. Confirm the Auto Scaling Group launches a replacement.
8. Confirm the replacement becomes healthy.
9. Confirm RDS remains private and inaccessible from the public internet.

---

## Future Improvements

Potential production enhancements include:

* HTTPS with AWS Certificate Manager
* HTTP-to-HTTPS redirect
* Route 53 DNS
* GitHub Actions CI/CD
* Docker containerization
* ECS/Fargate deployment
* AWS Secrets Manager integration
* RDS Multi-AZ
* CloudWatch dashboard
* AWS WAF
* VPC Flow Logs
* AWS Backup
* Separate staging and production environments

---

## Skills Demonstrated

* AWS VPC
* Public and private subnet architecture
* Availability Zones
* Route tables
* Internet Gateway
* NAT Gateway
* Security Groups
* IAM
* EC2
* Launch Templates
* Auto Scaling
* Application Load Balancer
* Target Groups
* Health checks
* Amazon RDS PostgreSQL
* CloudWatch
* SNS
* Systems Manager
* Terraform
* Terraform modules
* Remote Terraform state
* Infrastructure as Code
* High availability design
* Cloud security
* Cost-aware architecture
* Operational readiness

---

## Project Goal

The goal of this project is to demonstrate the ability to design and manage a realistic AWS environment using Infrastructure as Code, with emphasis on **availability, security, scalability, monitoring, and operational best practices**.
