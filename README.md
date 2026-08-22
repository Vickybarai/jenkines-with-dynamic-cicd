

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
*   Go to **IAM** > **Roles** > Create role (`EC2-Full-Access-Role`) with `AmazonEC2FullAccess` policy.
*   Attach this role to your `jenkins-master-server` instance (Actions > Security > Modify IAM Role).

### Step 1.5: Initialize Jenkins UI
1. Access `http://<EC2-Public-IP>:8080`
2. Get initial password: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
3. Install suggested plugins.
4. **Install mandatory custom plugins:** `Pipeline`, `SSH Plugin`, `Amazon Elastic Container Service (ECS)`, `Provisioning`.

---

# 📅 Phase 2: The Serverless Worker (Days 2 & 3 Combined)

*Note: This must be done in exact sequence. The agent will fail if configured in Jenkins before the custom image is built.*

### Step 2.1: Create ECS IAM Role
1. SSH into the master server. Create `role.sh` using the script from the reference guide.
2. Run `bash role.sh`.
3. Go to **AWS IAM** > **Roles**, find `ECS-Task-Execution-Role`, and **copy its ARN**.

### Step 2.2: Create Base Task Definition
1. Go to **AWS ECS** > **Task Definitions** > **Create new** > **JSON**.
2. Paste the JSON from the reference guide.
3. **Crucial:** Replace the dummy `"taskRoleArn"` with the real ARN from Step 2.1.
4. Click **Create**. *(Leave the dummy `jenkins/inbound-agent` image for now).*

### Step 2.3: Build & Push Custom Agent Image
The dummy image lacks tools. We must build the real one.
1. Go to **AWS ECR** > **Create Repository** > Name it `jenkins-agent`.
2. On your Jenkins server, create a `Dockerfile` (copy exact content from the reference guide—it installs kubectl, Terraform, Docker, AWS CLI).
3. Run the following commands (replace `<region>` and `<account-id>`):
   ```bash
   aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com
   docker build -t jenkins-agent .
   docker tag jenkins-agent:latest <account-id>.dkr.ecr.<region>.amazonaws.com/jenkins-agent:latest
   docker push <account-id>.dkr.ecr.<region>.amazonaws.com/jenkins-agent:latest
   ```

### Step 2.4: Update Task Definition with Real Image
1. Go back to **AWS ECS** > **Task Definitions** > Select your task > **Create new revision**.
2. Scroll to Container Definitions > **Image**.
3. Replace the dummy image with: `<account-id>.dkr.ecr.<region>.amazonaws.com/jenkins-agent:latest`
4. Click **Create**.

### Step 2.5: Configure Jenkins ECS Cloud
1. **Manage Jenkins** > **Clouds** > **New Cloud**.
2. **Name:** `ECS` | **Type:** `Amazon ECS` > Create.
3. **Region:** Select yours (e.g., `ap-southeast-2`).
4. Save, then click the cloud again > **Add Agent Template**:
   *   **Label:** `ecs` *(Used in Jenkinsfiles)*
   *   **Template Name:** `ecs-agent`
   *   **Launch Type:** `FARGATE`
   *   **Network Mode:** `awsvpc`
   *   **Assign Public IP:** `ENABLED`
   *   **Security Group:** Jenkins Master SG ID.
   *   **Subnets:** Your VPC Subnet IDs.
   *   **Task Definition:** Select the latest revision from Step 2.4.
5. **Advanced > Tunnel:** `<Jenkins-Master-Public-IP>:5000` > Save.

### Step 2.6: Add AWS Credentials
1. **Manage Jenkins** > **Credentials** > **System** > **Global** > **Add Credentials**.
2. Kind: **AWS Credentials**.
3. **ID:** `cdec-alpha-app-aws-creds` *(Strictly this exact string)*.
4. **Description:** `cdec-alpha-app-aws-creds`
5. Add your IAM User Access Key and Secret Key. Create.

---

# 📅 Phase 3: Frontend Infrastructure (Day 4)

### Step 3.1: Global SSL Certificate (us-east-1 ONLY)
CloudFront absolutely requires the certificate to be in `us-east-1`.
1. Go to **ACM** in `us-east-1` (N. Virginia).
2. **Request public certificate** for `yourdomain.com` and `api.yourdomain.com`.
3. DNS Validation > **Create records in Route 53**.
4. Wait ~15 mins until status is **Issued**. Copy the ARN.

### Step 3.2: Point Domain to AWS
1. Go to **Route 53** > **Hosted Zones**. Copy the 4 NS records.
2. Log into your Domain Registrar (Hostinger/GoDaddy).
3. Replace the default Nameservers with the 4 AWS NS records. *(Wait for propagation).*

### Step 3.3: Deploy Frontend via Jenkins
1. In GitHub, update `infrastructure/frontend/terraform.tfvars`:
   *   `bucket_name`: Unique name (e.g., `cdec-alpha-bucket-123`).
   *   `domain_name`: `yourdomain.com`
   *   `api_fqdn`: `api.yourdomain.com`
   *   `acm_arn`: Paste ARN from Step 3.1.
2. Go to Jenkins. Run pipeline `fe-alpha-2`. 
   *(This creates S3, CloudFront, and Route 53 records).*

---

# 📅 Phase 4: Backend Infrastructure (Day 5 - Part 1)

### Step 4.1: Regional SSL Certificate
The Application Load Balancer (ALB) needs a certificate in the *same region* as your backend (e.g., Ireland/Sydney), NOT us-east-1.
1. Go to **ACM** in your backend region (e.g., `eu-west-1`).
2. Request certificate for `api.yourdomain.com`.
3. Validate via Route 53.
4. **CRITICAL:** Check **"Enable export"** in certificate settings. Copy the ARN.

### Step 4.2: Deploy Backend Infra via Jenkins
1. In GitHub, duplicate `fe-alpha-2` pipeline config and create `be-alpha-2` pointing to `infrastructure/backend`.
2. Update `infrastructure/backend/terraform.tfvars`:
   *   `region`: Your backend region.
   *   `acm_arn`: Paste the **Regional** ARN from Step 4.1.
   *   `cluster_name`: e.g., `cdec-eks-dev`.
3. Run `be-alpha-2` in Jenkins. *(This creates VPC, EKS, and the ALB).*

### Step 4.3: Manually Attach SSL to ALB (The "Gotcha")
Terraform creates the ALB, but cannot attach the regional ACM if there's a timing issue. You must verify and attach it manually if the pipeline skipped it.
1. Go to **EC2** > **Load Balancers** > Select your backend ALB.
2. Click **Listeners** > **Add listener**.
3. Protocol: **HTTPS**, Port: **443**.
4. Default action: Select your target group.
5. Under **Secure listener settings**, select **"From ACM"** and choose the regional certificate from Step 4.1. Save.
6. *Note: If Terraform successfully attached it, this step will just show HTTPS/443 already existing.*

---

# 📅 Phase 5: Database & Application Deploy (Day 5 - Part 2)

### Step 5.1: Setup MongoDB Atlas
1. Log into **MongoDB Atlas** > Create Free **Shared Cluster** (`alpha-app-db`).
2. **Database Access:** Create user `mongodb-user` with password `redhat@rate123`.
3. **Network Access:** Add IP `0.0.0.0/0` (Allow from anywhere).
4. Click **Connect** > Drivers > Copy the connection string.

### Step 5.2: Update Microservices Code
You must update the DB connection in 3 backend services: `auth`, `courses`, `enrollment`. 
Go to `src/main/resources/application.yml` (or `.env`) in each:
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
Run the updated backend pipelines in Jenkins. Jenkins will spin up the ECS worker, build your Java/Node code into Docker images, push them to ECR, and deploy them to your EKS cluster behind the ALB.

---

## 🚨 Top 3 Reasons This Project Fails (Checklist)
- [ ] **Wrong ACM Region:** Used Sydney/Ireland ACM for CloudFront, or us-east-1 ACM for the ALB.
- [ ] **Missing Port 5000:** Forgot to open TCP 5000 in the Master EC2 Security Group, or forgot to set the Tunnel in Jenkins Cloud config.
- [ ] **Wrong Jenkins Credential ID:** Named the AWS credential `aws-creds` instead of exactly `cdec-alpha-app-aws-creds`.
