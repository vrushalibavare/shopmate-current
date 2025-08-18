# ShopMate E-commerce Application

A simple e-commerce application built with Node.js and Express, designed to be deployed to AWS ECS Fargate.

## Features

- Product listing and details
- Shopping cart functionality
- Checkout process
- Order management
- Responsive design
- **Stateless architecture** with DynamoDB session storage
- **Auto-scaling** with ECS Fargate
- **Cloud-native design** for high availability

## Prerequisites

- Node.js (v14 or higher)
- AWS CLI configured with appropriate permissions
- Terraform (for infrastructure deployment)

## Getting Started

### Local Development

1. Clone the repository:
   ```
   git clone <repository-url>
   cd shopmate-current
   ```

2. Install dependencies:
   ```
   cd app
   npm install
   ```

3. Start the development server:
   ```
   npm run dev
   ```

4. Open your browser and navigate to `http://localhost:3000`

**Note**: For full functionality including cart and orders, deploy to AWS as the app requires DynamoDB for data persistence.

## Deployment to AWS ECS Fargate

### Using the Deployment Script

```
./infra/deploy.sh [environment] [region]
```

For example:
```
./infra/deploy.sh dev ap-southeast-1
```

This will:
1. Build and push the Docker image to ECR
2. Apply the Terraform configuration for the specified environment
3. Output the application URLs

### Manual Deployment

1. Build and tag the Docker image:
   ```
   docker build -t shopmate app/
   docker tag shopmate:latest <aws-account-id>.dkr.ecr.ap-southeast-1.amazonaws.com/shopmate:latest
   ```

2. Push the image to ECR:
   ```
   aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin <aws-account-id>.dkr.ecr.ap-southeast-1.amazonaws.com
   docker push <aws-account-id>.dkr.ecr.ap-southeast-1.amazonaws.com/shopmate:latest
   ```

3. Apply the Terraform configuration:
   ```
   cd infra/terraform/environments/dev  # or uat, prod
   terraform init
   terraform apply
   ```

## Environment Configuration

- **dev**: Development environment (1 instance)
- **uat**: User Acceptance Testing environment (2 instances)
- **prod**: Production environment (3 instances)

## Monitoring

The application includes comprehensive monitoring with multiple tools:

### CloudWatch Dashboard
- CPU and memory utilization
- Application logs
- Request counts and latency
- Access via AWS Console or deployment script output

### Prometheus Metrics
- Application performance metrics
- Custom business metrics
- Node.js runtime metrics
- Access at: `https://your-domain.com/prometheus`

### Grafana Dashboards
- Visual dashboards and charts
- Real-time monitoring
- Custom alerting
- Access at: `https://your-domain.com/grafana`

All monitoring URLs are provided in the deployment script output.

## Project Structure

- `app/` - Application code
  - `app.js` - Main application entry point
  - `models/` - Data models
  - `controllers/` - Request handlers
  - `routes/` - API routes
  - `views/` - EJS templates
  - `public/` - Static assets
  - `Dockerfile` - Container configuration
- `infra/` - Infrastructure as Code
  - `terraform/` - AWS infrastructure definitions
  - `deploy.sh` - Deployment script
  - `Dockerfile.prometheus` - Monitoring container
- `docs/` - Complete project documentation
- `testing/` - Test files

## Stateless Architecture

ShopMate implements a **true stateless architecture** for optimal cloud performance:

### **How It Works**
- **Session Storage**: User sessions stored in DynamoDB (not container memory)
- **Any Container**: Load balancer can route requests to any healthy container
- **Seamless Scaling**: New containers immediately functional without warm-up
- **High Availability**: Container failures don't affect user sessions

### **Example Flow**
```
1. User adds item → Container A → Stores session in DynamoDB
2. User views cart → Container B → Reads session from DynamoDB ✅
3. User checks out → Container C → Processes order with session data ✅
```

### **Benefits**
- ✅ **Perfect for autoscaling** - containers are interchangeable
- ✅ **No sticky sessions** - optimal load distribution
- ✅ **Cloud-native** - follows 12-factor app principles
- ✅ **Production-ready** - handles traffic spikes gracefully

### **Technical Implementation**
- **Session Store**: `connect-dynamodb` with automatic TTL cleanup
- **Shared State**: Cart, orders, and user data in DynamoDB
- **Container Independence**: Each container can serve any user

## Autoscaling Testing

Test the stateless autoscaling with provided scripts:

```bash
# Gentle load testing (recommended)
cd infra/scripts
./gentle-autoscaling.sh

# Monitor scaling in real-time
./monitor-scaling.sh
```

**Expected behavior:**
1. CPU increases to 70%+ → ECS scales containers
2. Load distributes across multiple containers
3. Cart/sessions work seamlessly across all containers

## Documentation

Complete documentation is available in the [`docs/`](docs/) directory:

- **[CI/CD Workflows](docs/CICD-WORKFLOWS.md)** - Deployment and workflow documentation
- **[Infrastructure](docs/TERRAFORM_DOCUMENTATION.md)** - Terraform and AWS setup
- **[Auto-scaling](docs/AUTOSCALING_GUIDE.md)** - Scaling configuration and testing