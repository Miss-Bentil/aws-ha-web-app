# Architecture Documentation

## 1. Overview

The AWS Highly Available Web Application uses a layered architecture distributed across two Availability Zones.

The design separates public-facing infrastructure from application and database infrastructure.

```text
                         INTERNET
                            |
                            v
                    +---------------+
                    |     ALB       |
                    | Public Subnets|
                    +-------+-------+
                            |
                +-----------+-----------+
                |                       |
                v                       v
          +-----------+           +-----------+
          | EC2 / ASG |           | EC2 / ASG |
          | Private A |           | Private B |
          +-----+-----+           +-----+-----+
                |                       |
                +-----------+-----------+
                            |
                            v
                    +---------------+
                    | RDS PostgreSQL|
                    | Private       |
                    +---------------+
```

All infrastructure is provisioned using Terraform.

---

## 2. Network Design

The VPC uses the CIDR range:

```text
10.0.0.0/16
```

The infrastructure is distributed across two Availability Zones:

* `eu-west-2a`
* `eu-west-2b`

Each Availability Zone contains one public and one private subnet.

```text
VPC: 10.0.0.0/16

Availability Zone A
├── Public Subnet:  10.0.1.0/24
└── Private Subnet: 10.0.11.0/24

Availability Zone B
├── Public Subnet:  10.0.2.0/24
└── Private Subnet: 10.0.12.0/24
```

### Public subnets

Public subnets have a default route to the Internet Gateway.

They host internet-facing infrastructure such as the Application Load Balancer and NAT Gateways.

### Private subnets

Private subnets do not have a direct route to the Internet Gateway.

They contain:

* EC2 application servers
* RDS PostgreSQL

Private EC2 instances use NAT Gateways when they need outbound internet access, for example, to download operating-system packages during initialization.

---

## 3. Traffic Flow

A normal application request follows this path:

```text
User
 |
 | HTTP / HTTPS
 v
Application Load Balancer
 |
 | HTTP :80
 v
EC2 Application Server
 |
 | PostgreSQL :5432
 v
RDS PostgreSQL
```

The ALB distributes requests across healthy EC2 instances.

The database is never directly exposed to users.

### Outbound traffic from EC2

```text
EC2
 |
 v
Private Route Table
 |
 v
NAT Gateway
 |
 v
Internet Gateway
 |
 v
Internet
```

This allows private instances to access external services without assigning public IP addresses to the application servers.

---

## 4. Security Boundaries

Each infrastructure tier has its own Security Group.

```text
Internet
   |
   | :80 / :443
   v
+-------------+
|    ALB SG   |
+------+------+
       |
       | :80
       v
+-------------+
|    EC2 SG   |
+------+------+
       |
       | :5432
       v
+-------------+
|    RDS SG   |
+-------------+
```

### ALB Security Group

Allows:

* TCP 80 from `0.0.0.0/0`
* TCP 443 from `0.0.0.0/0`

### EC2 Security Group

Allows:

* TCP 80 only from the ALB Security Group

The application servers therefore do not need to accept direct internet traffic.

### RDS Security Group

Allows:

* TCP 5432 only from the EC2 Security Group

This creates a controlled trust relationship between application and database tiers.

---

## 5. High Availability

The application layer is designed to remain available if an individual EC2 instance fails.

The Auto Scaling Group is configured with:

```text
Minimum:  2
Desired:  2
Maximum:  4
```

The instances are deployed across the two private subnets.

The Application Load Balancer operates across both public subnets and performs health checks against the application instances.

If an instance becomes unhealthy:

1. The ALB stops routing traffic to the unhealthy target.
2. The Auto Scaling Group can terminate/replace the unhealthy instance.
3. A replacement instance launches from the Launch Template.
4. The new instance installs Nginx through user data.
5. Once healthy, the instance becomes available to the ALB.

This reduces the impact of individual instance failure.

---

## 6. NAT Gateway Design

The architecture uses one NAT Gateway per Availability Zone.

```text
AZ-A                          AZ-B
 |                             |
 v                             v
NAT Gateway A              NAT Gateway B
 |                             |
 +-------------+---------------+
               |
          Internet Gateway
```

This improves Availability Zone independence because private resources in each AZ can use the NAT Gateway in their own AZ.

The trade-off is cost: NAT Gateways incur charges even when they are not heavily used.

For a production environment, the resilience benefit would be weighed against traffic requirements and cost.

---

## 7. Compute Design

The EC2 layer uses an Auto Scaling Group backed by a Launch Template.

The Launch Template defines:

* Amazon Linux 2023
* `t3.micro`
* EC2 Security Group
* IAM instance profile
* Nginx installation
* Basic application test page

The Amazon Linux AMI is retrieved using the AWS Systems Manager public parameter rather than hard-coding a specific AMI ID.

This makes the configuration less dependent on a particular AMI identifier.

---

## 8. IAM Design

EC2 instances receive an IAM role through an instance profile.

The role currently provides:

### Systems Manager

`AmazonSSMManagedInstanceCore`

Used for secure administrative access through AWS Systems Manager.

### CloudWatch

`CloudWatchAgentServerPolicy`

Used to support CloudWatch monitoring from the instances.

The design avoids opening SSH port 22 to the internet.

---

## 9. Load Balancer Design

The Application Load Balancer is internet-facing and deployed across the public subnets.

It uses:

* ALB Security Group
* Target Group
* HTTP listener
* Health checks

The target group checks:

```text
GET /
```

A successful HTTP `200` response indicates that the target is healthy.

The ALB then routes traffic only to healthy targets.

HTTPS is intentionally left as a future enhancement because it requires a domain and ACM certificate for the complete implementation.

---

## 10. Database Design

Amazon RDS PostgreSQL is deployed inside the private subnets.

The database configuration includes:

* PostgreSQL 17
* `db.t3.micro`
* 20 GB GP3 storage
* Public access disabled
* Seven-day backup retention
* AWS-managed master password
* Single-AZ deployment

The database does not accept connections from the public internet.

Only resources associated with the EC2 Security Group can access PostgreSQL on port 5432.

### Development trade-off

Multi-AZ is disabled for the current configuration to reduce development cost.

For a production deployment, Multi-AZ would be evaluated based on availability requirements and budget.

---

## 11. Monitoring

CloudWatch monitors CPU utilization for the Auto Scaling Group.

The current alarm triggers when:

```text
Average CPU > 70%
for 2 consecutive periods
with each period = 5 minutes
```

An SNS topic is configured as the alarm destination.

Additional production monitoring could include:

* ALB unhealthy target count
* ALB 5xx responses
* RDS CPU utilization
* RDS free storage
* Application health
* Request latency
* CloudWatch dashboards

---

## 12. Remote Terraform State

The development environment uses an S3 backend for Terraform state.

```text
S3 Bucket
└── aws-ha-web-app/dev/terraform.tfstate
```

The state bucket is configured with:

* Server-side encryption
* Versioning
* Public access blocking
* Terraform state locking

The state infrastructure is bootstrapped separately from the application infrastructure.

This prevents the application environment from depending on locally stored Terraform state.

---

## 13. Terraform Module Design

The infrastructure is separated into reusable modules:

```text
modules/
├── networking/
├── security/
├── compute/
├── load_balancer/
├── database/
└── monitoring/
```

Each module has a clear responsibility.

For example:

```text
networking
    |
    +-- VPC
    +-- Subnets
    +-- Route Tables
    +-- Internet Gateway
    +-- NAT Gateways

security
    |
    +-- ALB Security Group
    +-- EC2 Security Group
    +-- RDS Security Group

compute
    |
    +-- IAM Role
    +-- Instance Profile
    +-- Launch Template
    +-- Auto Scaling Group

load_balancer
    |
    +-- Application Load Balancer
    +-- Target Group
    +-- Listener

database
    |
    +-- DB Subnet Group
    +-- RDS PostgreSQL

monitoring
    |
    +-- SNS Topic
    +-- CloudWatch Alarm
```

This structure makes the project easier to maintain and extend.

---

## 14. Key Design Decisions

### Why private subnets for EC2?

Application servers should not be directly exposed to the internet.

The ALB acts as the public entry point.

### Why private subnets for RDS?

Databases should not be publicly reachable.

Only the application tier needs database access.

### Why two Availability Zones?

Using multiple Availability Zones reduces dependency on a single physical AWS availability domain.

### Why Auto Scaling?

It provides automatic replacement of unhealthy instances and allows the application tier to scale between the configured minimum and maximum capacity.

### Why an ALB?

It provides a single public endpoint and distributes traffic between healthy application servers.

### Why Terraform?

Infrastructure as Code makes the environment reproducible, reviewable, version-controlled, and easier to modify consistently.

---

## 15. Development vs Production

This project intentionally balances realistic architecture with development cost.

| Area                    | Development     | Production Consideration                 |
| ----------------------- | --------------- | ---------------------------------------- |
| EC2                     | `t3.micro`      | Capacity-tested instance types           |
| ASG                     | 2–4 instances   | Based on workload                        |
| RDS                     | Single-AZ       | Multi-AZ                                 |
| RDS deletion protection | Disabled        | Enabled                                  |
| Final snapshot          | Skipped         | Recommended                              |
| ALB                     | HTTP            | HTTPS                                    |
| Monitoring              | Basic CPU alarm | Full observability                       |
| NAT                     | One per AZ      | Based on resilience/traffic requirements |
| Deployment              | Terraform       | CI/CD pipeline                           |

These choices are deliberate rather than accidental.

---

## 16. Future Architecture

The project can evolve toward a more production-oriented architecture:

```text
                       Route 53
                          |
                          v
                    AWS WAF / ACM
                          |
                          v
                         ALB
                          |
                          v
                    ECS / Fargate
                          |
                          v
                    RDS Multi-AZ
```

Additional improvements could include:

* HTTPS
* Route 53
* AWS WAF
* Docker
* ECS/Fargate
* GitHub Actions
* Secrets Manager
* VPC Flow Logs
* CloudWatch dashboards
* AWS Backup
* Separate staging and production environments

---

## 17. Summary

The architecture demonstrates a practical AWS approach to:

* Network segmentation
* High availability
* Horizontal scaling
* Controlled service-to-service communication
* Secure database placement
* Infrastructure monitoring
* IAM-based instance management
* Infrastructure as Code
* Remote Terraform state
* Cost-aware cloud design

The configuration is designed to be deployable without requiring architectural changes when moving from a development demonstration toward a production-ready implementation.
