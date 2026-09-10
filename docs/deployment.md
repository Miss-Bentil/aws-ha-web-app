# Deployment and Testing Guide

## Project Status

The Terraform configuration has been:

* Formatted
* Validated
* Successfully planned
* Configured to use remote Terraform state

The AWS application infrastructure has **not yet been deployed**.

This is intentional because several resources can incur ongoing AWS charges.

---

## Prerequisites

Before deploying, ensure you have:

* Terraform installed
* AWS CLI installed
* An authenticated AWS identity
* Appropriate AWS permissions
* Access to the project's Terraform state S3 bucket

Check Terraform:

```powershell
terraform version
```

Check AWS authentication:

```powershell
aws sts get-caller-identity
```

---

# 1. Initialize Terraform

Navigate to the development environment:

```powershell
cd environments/dev
```

Initialize Terraform:

```powershell
terraform init
```

Terraform will initialize the AWS provider and configure the S3 remote backend.

---

# 2. Format the Configuration

Run:

```powershell
terraform fmt -recursive
```

This ensures the Terraform files follow standard formatting.

---

# 3. Validate the Configuration

Run:

```powershell
terraform validate
```

Expected result:

```text
Success! The configuration is valid.
```

---

# 4. Review the Terraform Plan

Run:

```powershell
terraform plan
```

The plan should show the infrastructure Terraform intends to create.

The current expected plan is approximately:

```text
Plan: 34 to add, 0 to change, 0 to destroy.
```

The exact number may change if the configuration is modified later.

> `terraform plan` does not create AWS resources.

Always review the plan before applying infrastructure.

---

# 5. Apply the Infrastructure

Only perform this step when you are ready to create the AWS resources and incur applicable AWS charges.

Run:

```powershell
terraform apply
```

Review the proposed changes.

Terraform will ask for confirmation before creating the resources.

---

# 6. Retrieve Terraform Outputs

After deployment:

```powershell
terraform output
```

Useful outputs include:

* VPC ID
* Public subnet IDs
* Private subnet IDs
* ALB DNS name
* RDS endpoint
* RDS port
* Auto Scaling Group name
* Security Group IDs

The ALB DNS name is the primary endpoint for testing the application.

---

# 7. Test the Application

Copy the ALB DNS name from the Terraform output.

Open it in a browser.

The Nginx test page should display:

```text
AWS Highly Available Web Application

Server is running successfully.
```

You can also test from PowerShell:

```powershell
Invoke-WebRequest http://<ALB-DNS-NAME>
```

A successful response should return HTTP status `200`.

---

# 8. Verify the Auto Scaling Group

In AWS, verify that the Auto Scaling Group has:

```text
Minimum capacity: 2
Desired capacity: 2
Maximum capacity: 4
```

Confirm that two EC2 instances are running.

The instances should be distributed across the configured Availability Zones.

---

# 9. Verify ALB Target Health

Open the Application Load Balancer target group and check the registered targets.

Both EC2 instances should eventually show:

```text
Healthy
```

The ALB health check uses:

```text
Protocol: HTTP
Port: 80
Path: /
```

An unhealthy instance should not receive normal application traffic.

---

# 10. Test High Availability

This is one of the most important tests in the project.

### Step 1

Confirm both application instances are healthy.

### Step 2

Open the ALB DNS name and confirm the application works.

### Step 3

Terminate one of the EC2 instances manually.

Do not terminate both instances.

### Step 4

Refresh the application through the ALB.

The application should remain available because another instance is still serving traffic.

### Step 5

Monitor the Auto Scaling Group.

It should detect that capacity has fallen below the desired capacity and launch a replacement instance.

### Step 6

Wait for the replacement instance to:

1. Launch
2. Run the user-data script
3. Start Nginx
4. Register with the target group
5. Pass the ALB health check

The target should eventually return to:

```text
Healthy
```

This demonstrates the combined behavior of:

* Application Load Balancer
* Health checks
* Auto Scaling
* Multi-AZ application deployment

---

# 11. Test Systems Manager

The EC2 instances are configured with:

```text
AmazonSSMManagedInstanceCore
```

Use AWS Systems Manager Session Manager to connect to an instance.

The project intentionally does not require an inbound SSH rule.

This demonstrates a more secure operational access pattern.

---

# 12. Verify the Database

The RDS instance should have:

```text
Publicly accessible: No
```

The database is deployed in the private subnets.

The RDS Security Group permits PostgreSQL traffic only from the EC2 Security Group:

```text
EC2 → RDS
TCP 5432
```

The database should not be directly reachable from the public internet.

---

# 13. Verify Monitoring

Check CloudWatch for the Auto Scaling Group CPU alarm.

The current alarm is configured around:

```text
Metric: CPUUtilization
Threshold: 70%
Evaluation periods: 2
Period: 5 minutes
```

The alarm sends notifications to the configured SNS topic.

For a production environment, additional alarms should be added for application, load balancer, and database health.

---

# 14. Verify Remote State

Terraform state should be stored in the configured S3 backend rather than only on the local machine.

The development state path is:

```text
aws-ha-web-app/dev/terraform.tfstate
```

The S3 bucket is configured with encryption, versioning, public access blocking, and Terraform state locking.

This allows the Terraform state to be shared and managed centrally.

---

# 15. Destroy the Development Environment

When testing is complete, destroy the application infrastructure to avoid unnecessary ongoing charges:

```powershell
terraform destroy
```

Review the proposed resources before confirming.

The application infrastructure should be removed.

The separate Terraform state bucket should **not** be destroyed as part of the application environment.

---

# Cost Warning

The following resources can generate AWS charges:

* NAT Gateways
* EC2 instances
* Application Load Balancer
* RDS
* CloudWatch
* SNS
* Data transfer

The project therefore should not be left running unnecessarily.

For portfolio demonstrations, deploy only when testing and destroy the environment afterwards.

---

# Deployment Checklist

## Before deployment

* [ ] AWS credentials/configuration verified
* [ ] Terraform initialized
* [ ] Terraform formatted
* [ ] Terraform validated
* [ ] Terraform plan reviewed
* [ ] AWS cost implications understood

## After deployment

* [ ] Two EC2 instances running
* [ ] Instances distributed across Availability Zones
* [ ] ALB available
* [ ] ALB targets healthy
* [ ] Application page accessible
* [ ] RDS private
* [ ] Systems Manager access working
* [ ] CloudWatch alarm configured
* [ ] Remote state working

## High availability test

* [ ] Terminate one EC2 instance
* [ ] Application remains available
* [ ] Auto Scaling launches replacement
* [ ] Replacement becomes healthy
* [ ] Application returns to two healthy instances

## Cleanup

* [ ] Run `terraform destroy`
* [ ] Confirm billable resources are removed
* [ ] Verify the remote state bucket remains available
