    

# 🚀 DevOps Landing Zone & ECS Agent Setup 

## 🏗️ Architecture Overview
Before we start building, it's important to understand our goal. Traditionally, Jenkins uses "Static" worker nodes (permanent EC2 instances). In this project, we are upgrading to **"Dynamic" worker nodes** using AWS ECS. 

When a CI/CD pipeline runs, Jenkins will automatically spin up an ECS container, run the build, and destroy the container when finished. This saves costs and scales automatically.

![Jenkins Agent Architecture](https://z-cdn-media.chatglm.cn/files/42d049d7-7949-487d-8c58-534c062faef1.jpg?auth_key=1885944517-85a5dd6eefd44c68a9c29cbe54080789-0-5a0e6ad0d47c443c53bec6038e763a3e)

**Project Repository:** [cdec-alpha-app](https://github.com/AnupDudhe/cdec-alpha-app/tree/main)  
**Reference Guide:** [ECS-Node-Containers-Jenkins-Guide.md](https://github.com/AnupDudhe/cdec/blob/main/DevOps%20Essentials%20for%20Modern%20Engineering%2FJenkins%2FECS-Node-Containers-Jenkins-Guide.md)

---

***

# 🚀 Ultimate DevOps Project Blueprint (Days 1-5)

## 🗺️ The Complete Project Workflow
1. **Provision Control Hub:** EC2 instance with Jenkins, Docker, Terraform, AWS CLI.
2. **Provision Serverless Worker:** Create a custom Docker image containing DevOps tools, push to ECR, configure Jenkins to spin this container via ECS Fargate only when pipelines run.
3. **Frontend IaC:** Use Terraform to provision S3 (Hosting), CloudFront (CDN), and Route53 (DNS). Requires a Global SSL cert.
4. **Backend IaC:** Use Terraform to provision VPC, EKS Cluster, and Application Load Balancer (ALB). Requires a Regional SSL cert.
5. **Database & App Deploy:** Connect MongoDB Atlas to backend microservices, build app code, and deploy to EKS.

---

## 📁 Understanding the Project Repository Structure
You will be using this repo: [jenkines-with-dynamic-cicd](https://github.com/Vickybarai/jenkines-with-dynamic-cicd.git)

When you clone this repo, you will see a structure like this:
```text
jenkines-with-dynamic-cicd/
├── infrastructure/
│   ├── frontend/        <-- Maps to Phase 3 (Frontend IaC)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars  <-- YOU EDIT THIS FILE in Phase 3
│   └── backend/         <-- Maps to Phase 4 (Backend IaC)
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars  <-- YOU EDIT THIS FILE in Phase 4
├── frontend-app/        <-- Your actual frontend code
├── backend-app/         <-- Your actual backend microservices (auth, courses, etc.)
└── Jenkinsfile         <-- Tells Jenkins how to build the code
```
**How it works:** The `Jenkinsfile` uses the `ecs` agent label we setup in Phase 2. When it runs, it changes into the `infrastructure/frontend` folder and runs Terraform to build the AWS cloud.

---

# 📅 Phase 1: The Control Hub (Day 1)

### Step 1.1: Launch EC2 Instance
*   **Name:** `jenkins-master-server`
*   **OS:** Ubuntu 22.04 LTS
*   **Instance Type:** `t3.medium`
*   **Storage:** 30 GB
*   **Key Pair:** Select your `.pem` key.
*   **Security Group (Inbound Rules):** Allow **SSH (22)**, **HTTP (8080)**, and **Custom TCP (5000)**. *(Port 5000 is mandatory for Jenkins to communicate with the ECS worker).*

### Step 1.2: Install Tools via Script
SSH into the instance and run the master setup script (excludes Ansible as per project specs).
```bash
wget https://raw.githubusercontent.com/AnupDudhe/cdec/main/devops_stack.sh
chmod +x devops_stack.sh
sudo ./devops_stack.sh
```

### Step 1.3: Docker Permissions for Jenkins
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### Step 1.4: Attach IAM Role to EC2
*Manual UI:* Go to **IAM** > **Roles** > Create role (`EC2-Full-Access-Role`) with `AmazonEC2FullAccess` policy. Go to EC2 > Attach.

<details>
<summary>⚡ Click to view: AWS CLI - Attach IAM Role</summary>

> 🛑️ **BEGINNERS: What to change before running!**
> *   **`INSTANCE_ID`**: Go to your AWS EC2 Console, click on your `jenkins-master-server`, and copy the **Instance ID** (looks like `i-0abcd1234efgh5678`). Paste it below without quotes.
> *   **`ROLE_NAME`**: Leave this as `EC2-Full-Access-Role` unless you specifically named your IAM role something else in the manual steps.

```bash
# 1. Create an IAM Instance Profile wrapping the role
aws iam create-instance-profile \
    --instance-profile-name EC2-Full-Access-Role \
    --region us-east-1

aws iam add-role-to-instance-profile \
    --instance-profile-name EC2-Full-Access-Name \
    --role-name EC2-Full-Access-Role \
    --region ap-southeast-2

# 2. Attach it to your running EC2 instance
INSTANCE_ID="i-0abcd1234efgh5678" # <--- CHANGE THIS
aws ec2 associate-iam-instance-profile \
    --instance-id $INSTANCE_ID \
    --iam-instance-profile-name EC2-Full-Access-Role \
    --region us-east-1
```
</details>

### Step 1.5: Initialize Jenkins UI
1. Access `http://<EC2-Public-IP>:8080`
2. Get initial password: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
3. Install suggested plugins.
4. **Install mandatory custom plugins:** `Pipeline`, `SSH Plugin`, `Amazon Elastic Container Service (ECS)`, `Provisioning`.

### Step 1.6: Configure GitHub Webhooks (How Jenkins knows when you push code)
*Context: Jenkins doesn't magically know when you run `git push` on GitHub. It uses two methods to check for new code:*
1. **Polling (Default):** Jenkins checks GitHub every 5 minutes. *(Easy, but takes up to 5 mins to start).*
2. **Webhooks (Instant):** GitHub instantly messages Jenkins to start the pipeline the second you push.

<details>
<summary>⚙️ Click to view: How to set up the Webhook in GitHub for instant triggers</summary>

1. Go to your repository on GitHub > **Settings** > **Webhooks** > **Add webhook**.
2. **Payload URL:** `http://<Your-Jenkins-Public-IP>:8080/github-webhook/`
3. **Content type:** `application/json`
4. **Secret:** (Leave blank for now, add a secret later for security if needed).
5. **Which events trigger the pipeline?** Just select **Just the push event**.
6. **Active:** Check the box.
7. Click **Add webhook**.
*(You will need to do this for `fe-alpha-2`, `be-alpha-2`, and any microservice repo you deploy later).*
</details>

---

# 📅 Phase 2: The Foundation - Cluster, Role & Task Def (Days 2 & 3 Combined)

> ⚠️ **CRITICAL PREREQUISITE BEFORE STARTING:** 
> You **must** enable the TCP port for inbound agents inside Jenkins itself, not just the AWS Security Group.
> 1. Go to `Manage Jenkins` → `Configure Global Security`.
> 2. Scroll to **Agents** section.
> 3. Select **Fixed** and set it to `5000`. Click **Save**.

### Step 2.1: Create the ECS Cluster (THE DEPENDENCY)
*Logic Check: Jenkins cannot use an ECS Task Definition if the cluster doesn't exist yet. We must create it first.

<details>
<summary>📁 Click to view: create-ecs-cluster.sh</summary>

> 🛑️ **BEGINNERS: What to change before running!**
> *   **`CLUSTER_NAME`**: Keep as `cdec-ecs-cluster` unless told otherwise. *(The Jenkinsfile looks for this specific cluster name)*.
> *   **`REGION`**: Change `us-east-1` to the AWS region you are working in.

```bash
#!/bin/bash
CLUSTER_NAME="cdec-ecs-cluster"
REGION="us-east-1" # <--- CHANGE THIS REGION IF NEEDED

echo "🔐 Ensuring ECS Service-Linked Role exists..."
aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com 2>/dev/null || true

echo "🚀 Creating ECS Cluster: $CLUSTER_NAME"
aws ecs create-cluster \
    --cluster-name $CLUSTER_NAME \
    --region $REGION \
    --capacity-providers FARGATE \
    --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 \
    --settings name=containerInsights,value=enabled

echo "✅ ECS Cluster created successfully!"
```
</details>

### Step 2.2: Create CloudWatch Log Group

<details>
<summary>📁 Click to view: create-log-group.sh</summary>

> 🛑️ **BEGINNERS: What to change before running!**
> *   **`--region`**: Change `us-east-1` to the AWS region you are working in.

```bash
aws logs create-log-group \
  --log-group-name /ecs/jenkins-agent \
  --region us-east-1 # <--- CHANGE THIS REGION IF NEEDED
```
</details>

### Step 2.3: Create IAM Role for ECS
1. SSH into your master server. Create `role.sh` using the script below.
2. Run `bash role.sh`.
3. Go to **AWS IAM** > **Roles**, find `ECS-Task-Execution-Role`, and **copy its ARN**.

<details>
<summary>📁 Click to view: role.sh</summary>

> 🛑️ **BEGINNERS: What to change before running!**
> *   **`ROLE_NAME`**: Leave this as `ECS-Task-Execution-Role` unless instructed otherwise.
> *   **`--region`**: Change `us-east-1` to the AWS region you are working in.
> *   **Output:** When this finishes, it will print an ARN. **Write that ARN down**, you need it in Step 2.4!

```bash
#!/bin/bash
ROLE_NAME="ECS-Task-Execution-Role"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1" # <--- CHANGE THIS REGION IF NEEDED

aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{ "Effect": "Allow", "Principal": { "Service": "ecs-tasks.amazonaws.com" }, "Action": "sts:AssumeRole" }]
    }' --region $REGION 2>/dev/null || true

aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy \
    --region $REGION

aws iam put-role-policy \
    --role-name $ROLE_NAME \
    --policy-name JenkinsAgentPermissions \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            { "Effect": "Allow", "Action": ["ecs:RunTask", "ecs:RegisterTaskDefinition", "ecs:DescribeTasks", "ecs:DescribeClusters", "ecr:GetAuthorizationToken", "ecr:BatchGetImage", "logs:CreateLogStream", "logs:PutLogEvents", "iam:PassRole"], "Resource": "*" }
        ]
    }' --region $REGION

echo "✅ Role ARN: arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME"
```
</details>

### Step 2.4: Create Base Task Definition
> ⚠️ **IMPORTANT NOTE:** When creating ECS task definitions for Jenkins agents, **DO NOT** set `JENKINS_SECRET` or `JENKINS_AGENT_NAME` as environment variables. These are automatically provided by the Jenkins ECS plugin and setting them manually will cause the "Cannot provide secret via both named and positional arguments" error.

1. Go to **AWS ECS** > **Task Definitions** > **Create new** > **JSON**.
2. Paste the JSON below. Replace the `"executionRoleArn"` with the ARN you got from Step 2.3.
3. Click **Create**. *(We will upgrade the resources and image in Step 2.5/2.6).*

<details>
<summary>📁 Click to view: base-task-definition.json</summary>

> 🛑️ **BEGINNERS: What to change before saving in AWS!**
> *   **`executionRoleArn`**: Replace the dummy text with the ARN you copied from the terminal after running Step 2.3 (e.g., `arn:aws:iam::123456789012:role/ECS-Task-Execution-Role`).
> *   **`awslogs-region`**: Make sure this matches the region you are working in.

```json
{
    "family": "jenkins-agent",
    "containerDefinitions": [{
        "cpu": 0, "environment": [], "essential": true, "image": "jenkins/inbound-agent:latest",
        "logConfiguration": { "logDriver": "awslogs", "options": { "awslogs-group": "/ecs/jenkins-agent", "awslogs-region": "us-east-1", "awslogs-stream-prefix": "ecs" } },
        "mountPoints": [], "name": "jenkins-agent", "portMappings": [], "systemControls": [], "volumesFrom": []
    }],
    "executionRoleArn": "REPLACE_WITH_REAL_ARN_FROM_STEP_2.3",
    "networkMode": "awsvpc", "volumes": [], "placementConstraints": [],
    "requiresCompatibilities": ["FARGATE"], "cpu": "512", "memory": "1024"
}
```
</details>

### Step 2.5: Add AWS Credentials
1. Go to Manage Jenkins > Credentials > System > Global credentials (unrestricted) > Add Credentials.
2. Kind: Select AWS Credentials.
3. AWS Access Key ID: Paste your Access Key ID here.
4. AWS Secret Access Key: Paste your Secret Access Key here.
5. ID: `cdec-alpha-app-aws-creds` (MUST be exactly this string, no spaces, no typos!)
6. Description: `cdec-alpha-app-aws-creds`
  Click Create.

### Step 2.6: Configure Jenkins ECS Cloud

*   **Name:** `ECS`
*   **Amazon ECS Credentials:** Click the dropdown and select `cdec-alpha-app-aws-creds` (The one we made in Step 2.5).
*   **Assumed Role ARN:** *Leave Blank*
*   **Amazon ECS Region Name:** `us-east-1` *(Change this ONLY if you built your infrastructure in a different region like Sydney or Ireland. If you followed the scripts exactly, keep it `us-east-1`)*
*   **ECS Cluster:** Click the dropdown. Select the cluster you created in Step 2.1 (`cdec-ces-cluster`). *(If it doesn't appear, refresh the page or wait 2 minutes for AWS to finish creating it).*
*   Click **Save** (Do NOT click Add Agent Template yet).

### Step 2.7: Add Agent Template inside ECS Cloud
*(After you click Save, click on the word "ECS" that appears, then click "Add Agent Template")*

> ⚠️ **CRITICAL RULE:** Because we updated the CPU, Memory, and Docker Image directly inside the AWS Console, you must **LEAVE BLANK** any fields that duplicate those settings. If you fill them out here, Jenkins will override your AWS settings and the pod will fail to start.

*   **Label:** `ecs` *(Do not change this, your Jenkinsfile looks for this exact word)*
*   **Template Name:** `ecs-agent`
*   **Agent Container Name:** *Leave Blank*
*   **Task Definition Override:** *Leave Blank* 
*   **Docker Image:** *Leave Blank*
*   **Secrets manager ARN:** *Leave Blank*
*   **Launch type:** Select `FARGATE`
*   **Operating System Family:** **⚠️ MUST CHANGE TO `LINUX`** *(Jenkins defaults to Windows, which will crash our Ubuntu Dockerfile!)*
*   **CPU Architecture:** `X86_64`
*   **Default Capacity Provider:** *Leave Default*
*   **Capacity provider strategy:** *Leave Default*
*   **Network mode:** `awsvpc`
*   **Filesystem root:** *Leave Default (`/home/jenkins`)*
*   **Platform Version:** `LATEST`
*   **Soft Memory Reservation:** `0` *(Leave as 0)*
*   **Hard Memory Reservation:** `0` *(Leave as 0)*
*   **CPU units:** `0` *(Leave as 0)*
*   **Ephemeral Storage:** `0` *(Leave as 0)*
*   **Subnets:** Paste your VPC Subnet IDs here, separated by commas (e.g., `subnet-0a1b2c3d4e5f6g7h8, subnet-1a2b3c4d5e6f7g8h9`)
*   **Security Groups:** Paste your Jenkins Master Security Group ID here (e.g., `sg-0a1b2c3d4e5f6g7h8`)
*   **Assign Public Ip:** `ENABLED`
*   **Task Role ARN:** *Leave Blank* *(The role is already baked into the AWS Task Definition)*
*   **Task Execution Role ARN:** *Leave Blank* *(Same reason)*

### 🔽 Part 3: The Tunnel (Hidden at the bottom!)
You have to scroll all the way to the bottom of the Agent Template box to find this. This is how the ECS worker talks back to Jenkins.

1. Scroll down to the **Advanced** section and expand it.
2. Find the field named **Tunnel**.
3. Enter: `<Your-Jenkins-Master-Public-IP>:5000` *(Example: `13.51.123.45:5000`)*
4. Click **Save** at the very bottom. 

You are now done with Phase 2! Jenkins is officially configured to spin up your custom, heavy-duty DevOps container whenever a pipeline asks for an `ecs` agent.

### Step 2.8: Build & Push Custom Agent Image
1. Go to **AWS ECR** > **Create Repository** > Name it `jenkins-agent-custom`. (Or use script below).
2. On your Jenkins server, create a `Dockerfile` and paste the exact content below.

<details>
<summary>⚡ Click to view: AWS CLI - Create ECR Repository</summary>

> 🛑️ **BEGINNERS: What to change before running!**
> *   **`--region`**: Change `us-east-1` to the AWS region you are working in.
> *   **`--repository-name`**: Leave as `jenkins-agent-custom` unless told otherwise.

```bash
aws ecr create-repository --repository-name jenkins-agent-custom --region us-east-1
```
</details>

<details>
<summary>🐳 Click to view: Custom Jenkins Agent Dockerfile</summary>
    
*(No changes needed here, just copy and paste the whole block into a file named `Dockerfile` on your server)*

```dockerfile
FROM jenkins/inbound-agent:latest
USER root

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl wget git unzip \
    apt-transport-https ca-certificates gnupg lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Install Docker (Using native Debian repos to avoid Docker CDN 403 errors)
RUN apt-get update && apt-get install -y docker.io

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x ./kubectl && mv ./kubectl /usr/local/bin/kubectl

# Install Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Terraform (Corrected for Debian)
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && apt-get install -y terraform && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws/

# Add jenkins user to docker group
RUN usermod -aG docker jenkins
USER jenkins
```
</details>

<details>
<summary>📁 Click to view: build-and-push.sh</summary>

> 🛑️ **BEGINNERS: What to change before running!**
> *   **`REGION`**: Change `us-east-1` to the AWS region you are working in (must match the ECR repo region).
> *   **`REPO_NAME`**: Leave as `jenkins-agent-custom` unless told otherwise.
> *   *Note: Do NOT change `ACCOUNT_ID`, the script finds it automatically.*

```bash
#!/bin/bash
REGION="us-east-1" # <--- CHANGE THIS REGION
REPO_NAME="jenkins-custom"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IMAGE_TAG="latest"

docker build -t jenkins-agent-custom:$IMAGE_TAG .
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
docker tag jenkins-agent-custom:$IMAGE_TAG $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:$IMAGE_TAG
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:$IMAGE_TAG
echo "✅ Image URI: $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:$IMAGE_TAG"
```
</details>

### Step 2.9: Update Task Definition with Real Image
Now we update the blueprint to use the real image and increase CPU/Memory for Terraform/K8s builds.
1. Go back to **AWS ECS** > **Task Definitions** > Select your task > **Create new revision**.
2. Change **CPU** to `2048` and **Memory** to `4096`.
3. Scroll to Container Definitions > **Image**.
4. Replace the dummy image with the **Image URI** printed at the end of Step 2.8 (e.g., `123456789012.dkr.ecr.us-east-1.amazonaws.com/jenkins-custom:latest`).
5. Click **Create**. 
---
### 🧠 Phase 2.10: Understanding the Terraform Architecture (How it works)

Before we run the Phase 3 pipelines, it is critical to understand how the Terraform code in the repository functions. **You NEVER edit `main.tf` or `variables.tf` manually.** 

Think of it like this:

```text
[variables.tf] (The Questionnaire) ---> [main.tf] (The Logic) <--- (reads from)
                 ^
                 |
                 [terraform.tfvars] (Your Answers)
```

#### 📂 1. Frontend Setup (`infrastructure/frontend/`)
The frontend Terraform builds an S3 bucket for hosting your React/Angular app, a CloudFront distribution to serve it globally, and Route53 DNS to link your custom domain. 

**1. Open `infrastructure/frontend/variables.tf`**
This file contains the "blanks" Terraform needs filled in to build the frontend cloud.

<details>
<summary>📁 Click to view: What's inside `infrastructure/frontend/variables.tf`?</summary>

```hcl
variable "bucket_name" {
  description = "A globally unique name for the S3 bucket (e.g., cdec-alpha-bucket-123456)"
  type        = string
}

variable "domain_name" {
  description = "Your registered domain (e.g., myapp.com). Leave BLANK if using Sandbox Mode."
  type        = string
  default     = "" 
  # ⚠️ SANDBOX NOTE: If blank, Terraform will skip Route53 and ACM, and give you a default CloudFront URL.
}

variable "api_fqdn" {
  description = "Subdomain for your backend API (e.g., api.myapp.com). Leave BLANK if using Sandbox Mode."
  type        = string
  default     = "" 
}

variable "acm_arn" {
  description = "ARN of the SSL certificate in us-east-1 for CloudFront. Leave BLANK if using Sandbox Mode."
  type        = string
  default     = "" 
}

variable "region" {
  description = "AWS Region where the frontend resources will live."
  type        = string
  default     = "us-east-1"
}
```
</details>

**File:** `infrastructure/frontend/main.tf` (The Logic)
This file contains the actual AWS logic. It uses `var.bucket_name` to create the S3 bucket, `var.domain_name` to create Route 53 records, and `var.acm_arn` to attach the SSL cert to CloudFront. Because you are leaving domains blank in `.tfvars`, Terraform knows to skip those specific steps.

<details>
<summary>📁 Click to view: What's inside `infrastructure/frontend/main.tf`? (Simplified)</summary>

```hcl
# 1. S3 Bucket for React/Angular build artifacts
resource "aws_s3_bucket" "frontend-bucket" {
  bucket = var.bucket_name
}

# 2. CloudFront Distribution (CDN)
resource "aws_cloudfront_distribution" "frontend-cdn" {
  origin {
    domain_name = var.domain_name
  }
  enabled             = true
  
  # If domain is blank, Terraform assigns a default cloudfront.net URL automatically
  viewer_certificate_id = var.acm_arn
}
```
</details>

**File:** `infrastructure/frontend/terraform.tfvars` (YOUR CONFIGURATION)
This is the ONLY file you touch. You put your specific details here.

<details>
📁 Click to view: What to put in `infrastructure/frontend/terraform.tfvars` (Sandbox Mode)</summary>

```hcl
# ⚠️ SANDBOX MODE: No Domain Name
bucket_name = "cdec-frontend-bucket-123456" # MUST be globally unique (add random numbers at the end)
domain_name = ""                                # LEAVE BLANK
api_fqdn    = ""                                # LEAVE BLANK
acm_arn     = ""                                # LEAVE BLANK
region      = "us-east-1"                       # Your chosen AWS region
```
*(Result: Terraform will skip Route53 and ACM, and give you a default CloudFront URL like `https://d111111abcdef.cloudfront.net`)*
</details>

---

#### 📂 2. Backend Setup (`infrastructure/backend/`)
The backend Terraform builds the network foundation (VPC, Subnets, Route Tables, Internet Gateway) and the compute layer (EKS Cluster, Application Load Balancer) to run your microservices.

**1. Open `infrastructure/backend/variables.tf`**
<details>
<summary>📁 Click to view: What's inside `infrastructure/backend/variables.tf`?</summary>

```hcl
variable "region" {
  description = "AWS Region for the backend resources (VPC, EKS, ALB)"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name for your EKS cluster (e.g., cdec-ecs-dev)"
  type        = string
  default     = "cdec-ecs-dev"
}

variable "acm_arn" {
  description = "ARN of the Regional SSL certificate for the ALB (From Phase 4.1 or Sandbox Self-Signed cert)"
  type        = string
  default     = ""
}

variable "target_group_arn" {
  description = "ARN of the ALB Target Group (Terraform creates this automatically, or you find it in the AWS Console if manual attachment failed)"
  type        = string
  default     = ""
}
```
</details>

**File:** `infrastructure/backend/main.tf` (The Logic)
This file creates the networking (VPC, Subnets) and the compute layer (EKS Cluster, ALB) using your answers.

<details>
<summary>📁 Click to view: What's inside `infrastructure/backend/main.tf`? (Simplified)</summary>

```hcl
# 1. Create VPC, Subnets, Route Tables, Internet Gateway
module "network" {
  source  = "./network"
  region = var.region
}

# 2. Create EKS Cluster
resource "aws_eks_cluster" "eks-cluster" {
  name     = var.cluster_name
  region = var.region
}

# 3. Create Application Load Balancer
resource "aws_lb" "backend-alb" {
  name            = "${var.cluster_name}-alb"
  internal        = true
  security_groups = [aws_security_group.backend-sg.id]
  subnets        = module.network.public_subnets
}
```
</details>

**File:** `infrastructure/backend/terraform.tfvars` (YOUR CONFIGURATION)

<details>
📁 Click to view: What to put in `infrastructure/backend/terraform.tfvars` (Sandbox Mode)</summary>

```hcl
# ⚠️ SANDBOX MODE: No Domain Name
region         = "us-east-1"                       # Your backend region
cluster_name   = "cdec-ecs-dev"                   # Your EKS cluster name
acm_arn        = "arn:aws:acm:us-east-1:123456789012:certificate/..." # ARN from Phase 4.1 (or Sandbox self-signed cert)
target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/..." # ARN from Phase 4.3
```
*(Note: If `target_group_arn` is left blank, you will use the default AWS DNS name of the ALB to access your APIs, e.g., `https://internal-k8s-alb-123456789.us-east-1.elb.amazonaws.com/api/auth/login`)*
</details>

---

### 🔽 How Jenkins executes this (The `Jenkinsfile`)

When you run `fe-alpha-2` or `be-alpha-2` in Jenkins, the `Jenkinsfile` looks at the `infrastructure/` folder, runs `terraform init`, reads your answers from `terraform.tfvars`, and applies them using `main.tf`.

**Inside the repository's `Jenkinsfile` (Simplified example of what it does):**
```groovy
pipeline {
    agent { label 'ecs' } // Uses the dynamic ECS worker we built in Phase 2
    
    stages {
        stage('Terraform Init & Plan') {
            steps {
                dir 'infrastructure/frontend' // Changes into this directory
                sh 'terraform init'          // Initializes Terraform
                sh 'terraform plan -var-file=terraform.tfvars' // Dry-run using your tfvars
            }
        }
        stage('Terraform Apply') {
            steps {
                dir 'infrastructure/frontend'
                sh 'terraform apply -var-file=terraform.tfvars -auto-approve' // Actually builds the AWS cloud
            }
            
    }
}
```

---


# 📅 Phase 3: Frontend Infrastructure (Day 4)

### Step 3.1: Global SSL Certificate (us-east-1 ONLY)
CloudFront absolutely requires the certificate to be in `us-east-1`.

<details>
<summary>⚡ Click to view: AWS CLI - Request Global ACM Certificate</summary>

> 🛑️ **BEGINNERS: What to change before running!**
> *   **`--domain-name`**: Replace `yourdomain.com` with your actual registered domain (e.g., `infrasoftwarearchitect.online`).
> *   **`--subject-alternative-names`**: Replace `api.yourdomain.com` with your API subdomain (e.g., `api.infrasoftwarearchitect.online`).
> *   **`--region`**: DO NOT CHANGE. It absolutely MUST stay `us-east-1` for CloudFront.
> *   *Note:* After running this, you still MUST go to Route53 and create the CNAME validation records it outputs, then wait 15 mins for it to issue.

```bash
aws acm request-certificate \
  --domain-name yourdomain.com \
  --subject-alternative-names api.yourdomain.com \
  --validation-method DNS \
  --region us-east-1
```
</details>

<details>
<summary>🚨 SANDBOX MODE: If you DO NOT have a registered domain (No .com / .online)</summary>

If you do not have a registered domain name, **skip Step 3.1 and Step 3.2 entirely**. 
1. Open `infrastructure/frontend/terraform.tfvars`.
2. Leave the domain variables **blank**:
   ```hcl
   bucket_name = "cdec-alpha-bucket-123" # Make this unique
   domain_name = ""                    # LEAVE BLANK
   api_fqdn    = ""                    # LEAVE BLANK
   acm_arn     = ""                    # LEAVE BLANK
   ```
3. Run the `fe-alpha-2` pipeline. 
4. **How to access your frontend:** Terraform will output a default CloudFront URL in the logs (looks like `https://d12345abcdef.cloudfront.net`). Use this URL instead of a custom domain name.
</details>

### Step 3.2: Point Domain to AWS
*(Skip this step if you are using Sandbox Mode above)*
1. Go to **Route 53** > **Hosted Zones**. Copy the 4 NS records.
2. Log into your Domain Registrar (Hostinger/GoDaddy).
3. Replace the default Nameservers with the 4 AWS NS records.

### Step 3.3: Deploy Frontend via Jenkins
1. In GitHub, update `infrastructure/frontend/terraform.tfvars` (if not using Sandbox Mode).
2. Go to Jenkins. Run pipeline `fe-alpha-2`. 

---

# 📅 Phase 4: Backend Infrastructure (Day 5 - Part 1)

### Step 4.1: Regional SSL Certificate
The Application Load Balancer (ALB) needs a certificate in the *same region* as your backend, NOT us-east-1.

<details>
<summary>⚡ Click to view: AWS CLI - Request Regional ACM Certificate</summary>

> 🛑️ **BEGINNERS: What to change before running!**
> *   **`--domain-name`**: Replace `api.yourdomain.com` with your API subdomain.
> *   **`--region`**: Change `us-east-1` to the region where your backend infrastructure (EKS/VPC) is located (e.g., `us-east-1`).

```bash
aws acm request-certificate \
  --domain-name api.yourdomain.com \
  --validation-method DNS \
  --region us-east-1 # <--- CHANGE THIS TO YOUR BACKEND REGION
```
</details>

<details>
<summary>🚨 SANDBOX MODE: If you DO NOT have a registered domain (No .com / .online)</summary>

Because you don't have a custom domain, you cannot validate an ACM certificate. We will generate a free "Self-Signed" certificate on your Jenkins server and import it into AWS.

Run this command in your Jenkins Master SSH terminal:

```bash
# 1. Generate a private key and a self-signed certificate valid for 365 days
# Replace "api.yourdomain.com" with ANY string (it won't actually be validated, 
# but ACM requires a domain name format to import it).
openssl req -x509 -newkey rsa:2048 -keyout private.key -out certificate.crt -days 365 -nodes -subj "/CN=api.sandbox.local"

# 2. Import the certificate into AWS ACM
# Change --region to your backend region (e.g., us-east-1)
aws acm import-certificate \
    --certificate fileb://certificate.crt \
    --private-key fileb://private.key \
    --region us-east-1
```
*(Copy the ARN that gets printed in the terminal output, you need it for Step 4.3!)*
</details>

### Step 4.2: Deploy Backend Infra via Jenkins
1. In GitHub, duplicate `fe-alpha-2` pipeline config and create `be-alpha-2` pointing to `infrastructure/backend`.
2. Update `infrastructure/backend/terraform.tfvars`:
   *   `region`: Your backend region.
   *   `acm_arn`: Paste the **Regional** ARN from Step 4.1 (or Sandbox Mode).
   *   `cluster_name`: e.g., `cdec-eks-dev`.
3. Run `be-alpha-2` in Jenkins. *(This creates VPC, EKS, and the ALB).*

### Step 4.3: Manually Attach SSL to ALB (The "Gotcha")
If Terraform created the ALB but couldn't attach the cert due to timing, you must do it manually.

<details>
<summary>⚡ Click to view: AWS CLI - Attach HTTPS Listener to ALB (Sandbox Mode)</summary>

> 🛑️ **BEGINNERS: What to change before running!**
> *   **`ALB_ARN`**: Go to AWS Console -> **EC2** -> **Load Balancers** -> Click your backend ALB -> Copy the long ARN at the top left.
> *   **`TARGET_GROUP_ARN`**: Go to AWS Console -> **EC2** -> **Target Groups** -> Click your target group -> Copy the long ARN at the top left.
> *   **`REGIONAL_ACM_ARN`**: Paste the ARN you got when you imported the self-signed certificate in Step 4.1.
> *   **`--region`**: Change `us-east-1` to the region where your backend is located.

```bash
# REPLACE THESE THREE ARNs WITH YOUR ACTUAL VALUES
ALB_ARN="arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/my-alb/1234567890abcdef"
TARGET_GROUP_ARN="arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/my-tg/1234567890abcdef"
REGIONAL_ACM_ARN="arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-1234-123456789012" 

aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTPS \
    --port 443 \
    --default-actions Type=forward,TargetGroupArn=$TARGET_GROUP_ARN \
    --certificates CertificateArn=$REGIONAL_ACM_ARN \
    --region us-east-1 # <--- CHANGE THIS TO YOUR BACKEND REGION
```
</details>

<details>
<summary>🚨 SANDBOX MODE: How to access your Backend API without a domain</summary>

Because you don't have a custom domain like `api.yourdomain.com`, you must use the default AWS DNS name that AWS automatically assigns to your Load Balancer.

1. Go to the **AWS Console** > **EC2** > **Load Balancers**.
2. Click on the Load Balancer created by Terraform.
3. Look for **DNS name** (it will look like `internal-alb-123456789.us-east-1.elb.amazonaws.com`). **Copy this URL.**
4. When testing your APIs in Postman, use this URL instead of `api.yourdomain.com` (e.g., `https://internal-alb-123456789.us-east-1.elb.amazonaws.com/api/auth/login`).

*(Note: Your browser will show a "Not Secure" warning because it's a self-signed certificate. This is completely normal for a sandbox environment. Click "Advanced" -> "Proceed" to view the app).*
</details>

---

# 📅 Phase 5: Database & Application Deploy (Day 5 - Part 2)

### Step 5.1: Setup MongoDB Atlas
1. Log into **MongoDB Atlas** > Create Free **Shared Cluster** (`alpha-app-db`).
2. **Database Access:** Create user `mongodb-user` with password `redhat@rate123`.
3. **Network Access:** Add IP `0.0.0.0/0` (Allow from anywhere).
4. Click **Connect** > Drivers > Copy the connection string.

### Step 5.2: Update Microservices Code
Go to `src/main/resources/application.yml` (or `.env`) in `auth`, `courses`, and `enrollment` services:
1. **DO NOT** change the `token` secrets or other base code.
2. Comment out the sample URL: `# sample_url = mongodb://localhost...`
3. Paste the Atlas string, replacing `<password>`:
   ```yaml
   url: mongodb+srv://mongodb-user:redhat@rate123@cluster0.xxxxx.mongodb.net/?retryWrites=true&w=majority
   ```
4. Commit and push all 3 services to GitHub.

### Step 5.3: Final Jenkinsfile Adjustments
Before deploying the backend code, the `Jenkinsfile` in each microservice repo needs two changes:
1.  **Label:** Change `agent { label 'ecs' }` to `agent { label 'ecs-2' }` (or your specific EKS node label).
2.  **ECR Repo:** Ensure the `aws ecr` push/pull commands in the Jenkinsfile point to the correct ECR repositories for your specific microservices.

### Step 5.4: Deploy Backend Application
Run the updated backend pipelines in Jenkins. Jenkins will spin up the ECS worker (using the heavy custom image with Kubectl/Terraform), build your Java/Node code, push them to ECR, and deploy them to your EKS cluster behind the ALB.

---

## 🚨 Top 3 Reasons This Project Fails (Checklist)
- [ ] **Wrong ACM Region:** Used Sydney/Ireland ACM for CloudFront, or us-east-1 ACM for the ALB.
- [ ] **Missing Port 5000:** Forgot to open TCP 5000 in the Master EC2 Security Group, *AND* forgot to set the TCP port in `Manage Jenkins` -> `Configure Global Security`.
- [ ] **Wrong Jenkins Credential ID:** Named the AWS credential `aws-creds` instead of exactly `cdec-alpha-app-aws-creds`.
- [ ] **Missing Cluster Dependency:** Tried to select the Task Definition in Jenkins *before* creating the ECS cluster in Step 2.1.
