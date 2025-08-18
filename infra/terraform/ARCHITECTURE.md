# ShopMate Infrastructure Architecture

## Overview
This document provides a comprehensive overview of the ShopMate e-commerce application infrastructure deployed on AWS using Terraform.

## Architecture Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                 INTERNET                                        │
└─────────────────────────────┬───────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            ROUTE 53 DNS                                        │
│  ┌─────────────────────┐   ┌─────────────────────┐                            │
│  │   Hosted Zone       │   │  SSL Certificate    │                            │
│  │  example.com        │   │    Validation       │                            │
│  └─────────────────────┘   └─────────────────────┘                            │
└─────────────────────────────┬───────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        APPLICATION LOAD BALANCER                               │
│  ┌─────────────────────┐   ┌─────────────────────┐                            │
│  │   HTTPS Listener    │   │   HTTP Listener     │                            │
│  │   Port 443          │   │   Port 80           │                            │
│  │   (SSL Termination) │   │   (Redirect to 443) │                            │
│  └─────────────────────┘   └─────────────────────┘                            │
└─────────────────────────────┬───────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              VPC (10.0.0.0/16)                                 │
│                                                                                 │
│  ┌─────────────────────────────────┐   ┌─────────────────────────────────┐     │
│  │        PUBLIC SUBNET A          │   │        PUBLIC SUBNET B          │     │
│  │       (10.0.1.0/24)             │   │       (10.0.2.0/24)             │     │
│  │     Availability Zone A         │   │     Availability Zone B         │     │
│  │                                 │   │                                 │     │
│  │  ┌─────────────────────────┐    │   │                                 │     │
│  │  │     NAT GATEWAY         │    │   │                                 │     │
│  │  │   (Internet Access)     │    │   │                                 │     │
│  │  └─────────────────────────┘    │   │                                 │     │
│  └─────────────────────────────────┘   └─────────────────────────────────┘     │
│                                                                                 │
│  ┌─────────────────────────────────┐   ┌─────────────────────────────────┐     │
│  │       PRIVATE SUBNET A          │   │       PRIVATE SUBNET B          │     │
│  │       (10.0.3.0/24)             │   │       (10.0.4.0/24)             │     │
│  │     Availability Zone A         │   │     Availability Zone B         │     │
│  │                                 │   │                                 │     │
│  │  ┌─────────────────────────┐    │   │  ┌─────────────────────────┐    │     │
│  │  │     ECS FARGATE         │    │   │  │     ECS FARGATE         │    │     │
│  │  │      TASKS              │    │   │  │      TASKS              │    │     │
│  │  │   (Auto-scaling)        │    │   │  │   (Auto-scaling)        │    │     │
│  │  │   Port 3000             │    │   │  │   Port 3000             │    │     │
│  │  └─────────────────────────┘    │   │  └─────────────────────────┘    │     │
│  └─────────────────────────────────┘   └─────────────────────────────────┘     │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                        INTERNET GATEWAY                                 │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           AWS MANAGED SERVICES                                 │
│                                                                                 │
│  ┌─────────────────────┐   ┌─────────────────────┐   ┌─────────────────────┐   │
│  │     DYNAMODB        │   │   SECRETS MANAGER   │   │        ECR          │   │
│  │                     │   │                     │   │                     │   │
│  │  ┌───────────────┐  │   │  ┌───────────────┐  │   │  ┌───────────────┐  │   │
│  │  │   Products    │  │   │  │ Session Secret│  │   │  │ Docker Images │  │   │
│  │  │     Table     │  │   │  └───────────────┘  │   │  │  Repository   │  │   │
│  │  └───────────────┘  │   └─────────────────────┘   │  └───────────────┘  │   │
│  │  ┌───────────────┐  │                             └─────────────────────┘   │
│  │  │    Orders     │  │                                                       │
│  │  │     Table     │  │   ┌─────────────────────┐                             │
│  │  └───────────────┘  │   │    CLOUDWATCH       │                             │
│  │  ┌───────────────┐  │   │                     │                             │
│  │  │     Carts     │  │   │  ┌───────────────┐  │                             │
│  │  │     Table     │  │   │  │   Dashboard   │  │                             │
│  │  └───────────────┘  │   │  │   & Logs      │  │                             │
│  └─────────────────────┘   │  └───────────────┘  │                             │
│                            └─────────────────────┘                             │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Resource Creation Flow

The Terraform configuration creates resources in the following logical order:

### 1. Networking Foundation
- **VPC**: Creates isolated network environment
- **Subnets**: Public subnets in multiple AZs for high availability
- **Internet Gateway**: Provides internet access
- **Route Tables**: Routes traffic between subnets and internet
- **Security Groups**: Controls network access (ports 80, 443, 3000)

### 2. SSL/TLS & DNS
- **Route53 Zone**: DNS management (existing or new)
- **ACM Certificate**: SSL certificate for HTTPS
- **DNS Validation**: Automated certificate validation
- **A Record**: Points domain to load balancer

### 3. Container Registry
- **ECR Repository**: Stores Docker images
- **Lifecycle Policy**: Manages image retention and cleanup

### 4. Database Layer
- **DynamoDB Tables**: 
  - Products (catalog data)
  - Orders (transaction data)
  - Carts (session data)

### 5. Secrets Management
- **Random Password**: Generates secure session secret
- **Secrets Manager**: Stores and manages application secrets

### 6. IAM Security
- **Execution Role**: Allows ECS to pull images and write logs
- **Task Role**: Allows application to access AWS services
- **Policies**: Fine-grained permissions for DynamoDB and Secrets Manager

### 7. Load Balancing
- **Application Load Balancer**: Distributes traffic across containers
- **Target Group**: Health checks and routing configuration
- **Listeners**: HTTPS (443) and HTTP redirect (80)

### 8. Container Orchestration
- **ECS Cluster**: Logical grouping of compute resources
- **Task Definition**: Container configuration and resource allocation
- **ECS Service**: Manages running tasks and load balancer integration
- **CloudWatch Logs**: Centralized logging

### 9. Auto Scaling
- **Scaling Target**: Defines min/max capacity
- **CPU Policy**: Scales based on CPU utilization (70% target)
- **Memory Policy**: Scales based on memory utilization (80% target)

### 10. Monitoring
- **CloudWatch Dashboard**: Operational visibility and metrics

## Environment-Specific Configurations

| Environment | App Count | Max Capacity | Use Case |
|-------------|-----------|--------------|----------|
| **dev**     | 1         | 5            | Development and testing |
| **uat**     | 2         | 5            | User acceptance testing |
| **prod**    | 3+        | 10           | Production workloads |

## Security Features

- **Network Isolation**: VPC with public subnets only for necessary resources
- **SSL/TLS Encryption**: End-to-end encryption with ACM certificates
- **Secrets Management**: Secure storage of sensitive data
- **IAM Least Privilege**: Minimal required permissions for each role
- **Security Groups**: Network-level access control

## High Availability & Resilience

- **Multi-AZ Deployment**: Resources distributed across availability zones
- **Auto Scaling**: Automatic capacity adjustment based on demand
- **Health Checks**: Load balancer monitors container health
- **Managed Services**: DynamoDB, Secrets Manager, and ECR provide built-in redundancy

## Monitoring & Observability

- **CloudWatch Dashboard**: Real-time metrics and operational insights
- **Application Logs**: Centralized logging with retention policies
- **Auto Scaling Metrics**: CPU and memory utilization tracking
- **Load Balancer Metrics**: Request count and response time monitoring

## Cost Optimization

- **Pay-per-Request DynamoDB**: No provisioned capacity charges
- **Fargate Pricing**: Pay only for running containers
- **ECR Lifecycle Policies**: Automatic cleanup of old images
- **CloudWatch Log Retention**: 30-day retention to control costs

## Deployment Dependencies

The resources have the following dependency chain:

```
VPC → Subnets → Security Groups → Load Balancer
                                      ↓
ECR Repository → Task Definition → ECS Service
                                      ↓
DynamoDB Tables → IAM Roles → Auto Scaling
                                      ↓
Route53 → SSL Certificate → CloudWatch Dashboard
```

This architecture ensures a robust, scalable, and secure e-commerce platform that follows AWS best practices for production workloads.