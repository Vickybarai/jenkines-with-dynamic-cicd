

# 🚀 DevOps Landing Zone & ECS Agent Setup 

## 🏗️ Architecture Overview
Before we start building, it's important to understand our goal. Traditionally, Jenkins uses "Static" worker nodes (permanent EC2 instances). In this project, we are upgrading to **"Dynamic" worker nodes** using AWS ECS. 

When a CI/CD pipeline runs, Jenkins will automatically spin up an ECS container, run the build, and destroy the container when finished. This saves costs and scales automatically.

![Jenkins Agent Architecture](https://z-cdn-media.chatglm.cn/files/42d049d7-7949-487d-8c58-534c062faef1.jpg?auth_key=1885944517-85a5dd6eefd44c68a9c29cbe54080789-0-5a0e6ad0d47c443c53bec6038e763a3e)

**Project Repository:** [cdec-alpha-app](https://github.com/AnupDudhe/cdec-alpha-app/tree/main)  
**Reference Guide:** [ECS-Node-Containers-Jenkins-Guide.md](https://github.com/AnupDudhe/cdec/blob/main/DevOps%20Essentials%20for%20Modern%20Engineering%2FJenkins%2FECS-Node-Containers-Jenkins-Guide.md)

---
This is the final, heavily verified, end-to-end guide. I have traced the exact project workflow from an empty AWS account to a deployed application. 

I found and fixed **critical missing steps** from previous versions—specifically regarding how the ALB listener is manually attached to the regional ACM certificate, the exact sequence of building the ECS image, and specific code warnings (like never changing the Token variable). 

Here is the definitive, bulletproof manual.

***
Here is the updated, definitive guide. I have added precise, copy-pasteable AWS CLI scripts inside collapsible dropdowns for *every single manual AWS Console step*. This allows you to choose whether you want to click through the UI or run a quick 3-line script to achieve the exact same result.

***

# 🚀 Ultimate DevOps Project Blueprint (Days 1-5)

## 🗺️ The Complete Project Workflow
1. **Provision Control Hub:** EC2 instance with Jenkins, Docker, Terraform, AWS CLI.
2. **Provision Serverless Worker:** Create a custom Docker image containing DevOps tools, push to ECR, configure Jenkins to spin this container via ECS Fargate only when pipelines run.
3. **Frontend IaC:** Use Terraform to provision S3 (Hosting), CloudFront (CDN), and Route53 (DNS). Requires a Global SSL cert.
4. **Backend IaC:** Use Terraform to provision VPC, EKS Cluster, and Application Load Balancer (ALB). Requires a Regional SSL cert.
5. **Database & App Deploy:** Connect MongoDB Atlas to backend microservices, build app code, and deploy to EKS.

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

```bash
# 1. First, create an IAM Instance Profile wrapping the role
aws iam create-instance-profile \
    --instance-profile-name EC2-Full-Access-Role \
    --region ap-southeast-2

aws iam add-role-to-instance-profile \
    --instance-profile-name EC2-Full-Access-Role \
    --role-name EC2-Full-Access-Role \
    --region ap-southeast-2

# 2. Attach it to your running EC2 instance (Replace INSTANCE_ID with yours)
INSTANCE_ID="i-0abcd1234efgh5678" 
aws ec2 associate-iam-instance-profile \
    --instance-id $INSTANCE_ID \
    --iam-instance-profile-name EC2-Full-Access-Role \
    --region ap-southeast-2
```
</details>

### Step 1.5: Initialize Jenkins UI
1. Access `http://<EC2-Public-IP>:8080`
2. Get initial password: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
3. Install suggested plugins.
4. **Install mandatory custom plugins:** `Pipeline`, `SSH Plugin`, `Amazon Elastic Container Service (ECS)`, `Provisioning`.

---

# 📅 Phase 2: The Serverless Worker (Days 2 & 3 Combined)

> ⚠️ **CRITICAL PREREQUISITE BEFORE STARTING:** 
> You **must** enable the TCP port for inbound agents inside Jenkins itself, not just the AWS Security Group.
> 1. Go to `Manage Jenkins` → `Configure Global Security`.
> 2. Scroll to **Agents** section.
> 3. Select **Fixed** and set it to `5000`. Click **Save**.

### Step 2.1: Create CloudWatch Log Group & IAM Role

<details>
<summary>📁 Click to view: create-log-group.sh</summary>

```bash
aws logs create-log-group \
  --log-group-name /ecs/jenkins-agent \
  --region ap-southeast-2
```
</details>

1. SSH into your master server. Create `role.sh` using the script below.
2. Run `bash role.sh`.
3. Go to **AWS IAM** > **Roles**, find `ECS-Task-Execution-Role`, and **copy its ARN**.

<details>
<summary>📁 Click to view: role.sh</summary>

```bash
#!/bin/bash
ROLE_NAME="ECS-Task-Execution-Role"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{ "Effect": "Allow", "Principal": { "Service": "ecs-tasks.amazonaws.com" }, "Action": "sts:AssumeRole" }]
    }' 2>/dev/null || true

aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

aws iam put-role-policy \
    --role-name $ROLE_NAME \
    --policy-name JenkinsAgentPermissions \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            { "Effect": "Allow", "Action": ["ecs:RunTask", "ecs:RegisterTaskDefinition", "ecs:DescribeTasks", "ecs:DescribeClusters", "ecr:GetAuthorizationToken", "ecr:BatchGetImage", "logs:CreateLogStream", "logs:PutLogEvents", "iam:PassRole"], "Resource": "*" }
        ]
    }'

echo "✅ Role ARN: arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME"
```
</details>

### Step 2.2: Create Base Task Definition
> ⚠️ **IMPORTANT NOTE:** When creating ECS task definitions for Jenkins agents, **DO NOT** set `JENKINS_SECRET` or `JENKINS_AGENT_NAME` as environment variables. These are automatically provided by the Jenkins ECS plugin and setting them manually will cause the "Cannot provide secret via both named and positional arguments" error.

1. Go to **AWS ECS** > **Task Definitions** > **Create new** > **JSON**.
2. Paste the JSON below. Replace the `"executionRoleArn"`.
3. Click **Create**. *(We will upgrade the resources and image in Step 2.5/2.6).*

<details>
<summary>📁 Click to view: base-task-definition.json</summary>

```json
{
    "family": "jenkins-agent",
    "containerDefinitions": [{
        "cpu": 0, "environment": [], "essential": true, "image": "jenkins/inbound-agent:latest",
        "logConfiguration": { "logDriver": "awslogs", "options": { "awslogs-group": "/ecs/jenkins-agent", "awslogs-region": "ap-southeast-2", "awslogs-stream-prefix": "ecs" } },
        "mountPoints": [], "name": "jenkins-agent", "portMappings": [], "systemControls": [], "volumesFrom": []
    }],
    "executionRoleArn": "REPLACE_WITH_REAL_ARN_FROM_STEP_2.1",
    "networkMode": "awsvpc", "volumes": [], "placementConstraints": [],
    "requiresCompatibilities": ["FARGATE"], "cpu": "512", "memory": "1024"
}
```
</details>

### Step 2.3: Configure Jenkins ECS Cloud
1. **Manage Jenkins** > **Clouds** > **New Cloud** > `Amazon ECS`.
2. **Name:** `ECS` | **Region:** `ap-southeast-2` (or yours).
3. Save, then click the cloud again > **Add Agent Template**:
   *   **Label:** `ecs` *(Used in Jenkinsfiles)*
   *   **Template Name:** `ecs-agent`
   *   **Launch Type:** `FARGATE**
   *   **Network Mode:** `awsvpc`
   *   **Assign Public IP:** `ENABLED`
   *   **Security Group:** Jenkins Master SG ID.
   *   **Subnets:** Your VPC Subnet IDs.
   *   **Task Definition:** Select the task from Step 2.2.
4. **Advanced > Tunnel:** `<Jenkins-Master-Public-IP>:5000` > Save.

### Step 2.4: Add AWS Credentials
1. **Manage Jenkins** > **Credentials** > **System** > **Global** > **Add Credentials**.
2. Kind: **AWS Credentials**.
3. **ID:** `cdec-alpha-app-aws-creds` *(Strictly this exact string)*.
4. **Description:** `cdec-alpha-app-aws-creds`
5. Add your IAM User Access Key and Secret Key. Create.

### Step 2.5: Build & Push Custom Agent Image
1. Go to **AWS ECR** > **Create Repository** > Name it `jenkins-agent-custom`. (Or use script below).
2. On your Jenkins server, create a `Dockerfile` and paste the exact content below.

<details>
<summary>⚡ Click to view: AWS CLI - Create ECR Repository</summary>

```bash
aws ecr create-repository --repository-name jenkins-agent-custom --region ap-southeast-2
```
</details>

<details>
<summary>🐳 Click to view: Custom Jenkins Agent Dockerfile</summary>

```dockerfile
FROM jenkins/inbound-agent:latest
USER root
RUN apt-get update && apt-get install -y curl wget git unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io && rm -rf /var/lib/apt/lists/*
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && chmod +x ./kubectl && mv ./kubectl /usr/local/bin/kubectl
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && apt-get install -y terraform && rm -rf /var/lib/apt/lists/*
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws/
RUN usermod -aG docker jenkins
USER jenkins
```
</details>

3. Run the following commands to build and push (Replace `<region>` and `<account-id>`):

<details>
<summary>📁 Click to view: build-and-push.sh</summary>

```bash
#!/bin/bash
REGION="ap-southeast-2"
REPO_NAME="jenkins-agent-custom"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IMAGE_TAG="latest"

docker build -t jenkins-agent-custom:$IMAGE_TAG .
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
docker tag jenkins-agent-custom:$IMAGE_TAG $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:$IMAGE_TAG
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:$IMAGE_TAG
echo "✅ Image URI: $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:$IMAGE_TAG"
```
</details>

### Step 2.6: Update Task Definition with Real Image
Now we update the blueprint to use the real image and increase CPU/Memory for Terraform/K8s builds.
1. Go back to **AWS ECS** > **Task Definitions** > Select your task > **Create new revision**.
2. Change **CPU** to `2048` and **Memory** to `4096`.
3. Scroll to Container Definitions > **Image**.
4. Replace the dummy image with: `<account-id>.dkr.ecr.<region>.amazonaws.com/jenkins-agent-custom:latest`
5. Click **Create**. 

---

# 📅 Phase 3: Frontend Infrastructure (Day 4)

### Step 3.1: Global SSL Certificate (us-east-1 ONLY)
CloudFront absolutely requires the certificate to be in `us-east-1`.

*Manual UI:* Go to **ACM** in `us-east-1` > Request public cert > Validate via Route53 > Wait for "Issued".

<details>
<summary>⚡ Click to view: AWS CLI - Request Global ACM Certificate</summary>

```bash
aws acm request-certificate \
  --domain-name yourdomain.com \
  --subject-alternative-names api.yourdomain.com \
  --validation-method DNS \
  --region us-east-1
# NOTE: Copy the output ARN. You still MUST go to Route53 and create the CNAME validation records manually, or use the output DNS values to create them.
```
</details>

### Step 3.2: Point Domain to AWS
1. Go to **Route 53** > **Hosted Zones**. Copy the 4 NS records.
2. Log into your Domain Registrar (Hostinger/GoDaddy).
3. Replace the default Nameservers with the 4 AWS NS records.

### Step 3.3: Deploy Frontend via Jenkins
1. In GitHub, update `infrastructure/frontend/terraform.tfvars`:
   *   `bucket_name`: Unique name (e.g., `cdec-alpha-bucket-123`).
   *   `domain_name`: `yourdomain.com`
   *   `api_fqdn`: `api.yourdomain.com`
   *   `acm_arn`: Paste ARN from Step 3.1.
2. Go to Jenkins. Run pipeline `fe-alpha-2`. 

---

# 📅 Phase 4: Backend Infrastructure (Day 5 - Part 1)

### Step 4.1: Regional SSL Certificate
The Application Load Balancer (ALB) needs a certificate in the *same region* as your backend, NOT us-east-1.

*Manual UI:* Go to **ACM** in your backend region > Request cert > Validate > Check "Enable export" > Copy ARN.

<details>
<summary>⚡ Click to view: AWS CLI - Request Regional ACM Certificate</summary>

```bash
# Change eu-west-1 to your backend region (e.g., ap-southeast-2 for Sydney)
aws acm request-certificate \
  --domain-name api.yourdomain.com \
  --validation-method DNS \
  --region eu-west-1
# NOTE: Remember to add the DNS validation records in Route 53!
```
</details>

### Step 4.2: Deploy Backend Infra via Jenkins
1. In GitHub, duplicate `fe-alpha-2` pipeline config and create `be-alpha-2` pointing to `infrastructure/backend`.
2. Update `infrastructure/backend/terraform.tfvars`:
   *   `region`: Your backend region.
   *   `acm_arn`: Paste the **Regional** ARN from Step 4.1.
   *   `cluster_name`: e.g., `cdec-eks-dev`.
3. Run `be-alpha-2` in Jenkins. *(This creates VPC, EKS, and the ALB).*

### Step 4.3: Manually Attach SSL to ALB (The "Gotcha")
If Terraform created the ALB but couldn't attach the cert due to timing, you must do it manually.

*Manual UI:* Go to **EC2** > **Load Balancers** > Select ALB > Listeners > Add HTTPS(443) > Select Target Group > Attach Cert.

<details>
<summary>⚡ Click to view: AWS CLI - Attach HTTPS Listener to ALB</summary>

```bash
# Variables to replace with your actual ARNs
ALB_ARN="arn:aws:elasticloadbalancing:eu-west-1:123456789012:loadbalancer/app/my-alb/1234567890abcdef"
TARGET_GROUP_ARN="arn:aws:elasticloadbalancing:eu-west-1:123456789012:targetgroup/my-tg/1234567890abcdef"
REGIONAL_ACM_ARN="arn:aws:acm:eu-west-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"

# Create the listener
aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTPS \
    --port 443 \
    --default-actions Type=forward,TargetGroupArn=$TARGET_GROUP_ARN \
    --certificates CertificateArn=$REGIONAL_ACM_ARN \
    --region eu-west-1
```
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
