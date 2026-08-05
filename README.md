

# 🚀 DevOps Landing Zone & ECS Agent Setup (Day 1 & 2)

## 🏗️ Architecture Overview
Before we start building, it's important to understand our goal. Traditionally, Jenkins uses "Static" worker nodes (permanent EC2 instances). In this project, we are upgrading to **"Dynamic" worker nodes** using AWS ECS. 

When a CI/CD pipeline runs, Jenkins will automatically spin up an ECS container, run the build, and destroy the container when finished. This saves costs and scales automatically.

![Jenkins Agent Architecture](https://z-cdn-media.chatglm.cn/files/42d049d7-7949-487d-8c58-534c062faef1.jpg?auth_key=1885944517-85a5dd6eefd44c68a9c29cbe54080789-0-5a0e6ad0d47c443c53bec6038e763a3e)

**Project Repository:** [cdec-alpha-app](https://github.com/AnupDudhe/cdec-alpha-app/tree/main)  
**Reference Guide:** [ECS-Node-Containers-Jenkins-Guide.md](https://github.com/AnupDudhe/cdec/blob/main/DevOps%20Essentials%20for%20Modern%20Engineering%2FJenkins%2FECS-Node-Containers-Jenkins-Guide.md)

---

# 📅 Day 1: Building the Control Hub (Jenkins Master)

## 🛠️ Prerequisites
1. **AWS Account** with billing enabled.
2. **SSH Key Pair:** Create `devops-key` (.pem) in AWS EC2 Console.
3. **Lock Key (Mac/Linux):** `chmod 400 /path/to/devops-key.pem`

## 📝 Step-by-Step Setup

### 1. Launch the Master EC2 Instance
*   **Name:** `jenkins-master-server`
*   **OS:** Ubuntu 22.04 LTS
*   **Instance Type:** `t3.medium`
*   **Storage:** 30 GB
*   **Security Group (Inbound Rules):** Allow **SSH (22)**, **HTTP (8080)**, and **Custom TCP (5000)** *(Port 5000 is critical for Day 2 ECS communication).*

### 2. Automate Tool Installation
SSH into the server and run the instructor's master script. This installs Java, Jenkins, Docker, Terraform, and AWS CLI (Note: *Ansible is intentionally excluded*).
```bash
wget https://raw.githubusercontent.com/AnupDudhe/cdec/main/devops_stack.sh
chmod +x devops_stack.sh
sudo ./devops_stack.sh
```

### 3. Fix Docker Permissions for Jenkins
Allow Jenkins to execute Docker commands by adding its user to the Docker group.
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### 4. Attach IAM Role to EC2
So the server can run Terraform to build AWS resources:
*   Go to **IAM** -> **Roles** -> Create `EC2-Full-Access-Role` (Attach `AmazonEC2FullAccess` policy).
*   Attach this role to your `jenkins-master-server` EC2 instance.

### 5. Initialize Jenkins UI
1. Open browser: `http://<EC2-Public-IP>:8080`
2. Get password: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
3. Install **Suggested Plugins**.
4. **Install 4 Custom Plugins:** Go to *Manage Jenkins > Plugins* and install: `Pipeline`, `SSH Plugin`, `Amazon Elastic Container Service (ECS)`, `Provisioning`.

---

# 📅 Day 2: Configuring the Dynamic Worker (ECS Agent)

*Concept: We will now configure Jenkins to spawn ECS Fargate containers as workers instead of using permanent EC2 instances.*

## 📝 Step-by-Step Setup

### 1. Create ECS Task Execution Role (IAM)
Containers need permissions to pull images and allocate CPU/RAM. 
1. SSH into your `jenkins-master-server`.
2. Create `role.sh` using the script from the [Reference Guide](https://github.com/AnupDudhe/cdec/blob/main/DevOps%20Essentials%20for%20Modern%20Engineering%2FJenkins%2FECS-Node-Containers-Jenkins-Guide.md).
3. Run `bash role.sh`.
4. Go to **AWS IAM Console** -> **Roles**, find `ECS-Task-Execution-Role`, and **copy its ARN**.

### 2. Create ECS Task Definition
This is the blueprint for your worker container.
1. Go to **AWS ECS Console** -> **Task Definitions** -> **Create new Task Definition** -> **JSON**.
2. Paste the Task Definition JSON from the [Reference Guide](https://github.com/AnupDudhe/cdec/blob/main/DevOps%20Essentials%20for%20Modern%20Engineering%2FJenkins%2FECS-Node-Containers-Jenkins-Guide.md).
3. **Crucial Step:** Find `"taskRoleArn"` in the JSON and replace the dummy ARN with the **real ARN** you copied in Step 1.
4. Click **Create**. *(Don't worry about the dummy image in the JSON yet, we fix that in Step 6).*

### 3. Configure Jenkins ECS Cloud
Tell Jenkins how to talk to AWS ECS.
1. Go to **Manage Jenkins** -> **Clouds** -> **New Cloud**.
2. **Name:** `ECS` | **Type:** `Amazon ECS` -> Click **Create**.
3. **Region:** Select your region (e.g., `ap-southeast-2`). *(If successful, it will automatically show your ECS Role).*
4. Click **Save**, then click the `ECS` cloud again to add a template:
   *   **Label:** `ECS`
   *   **Template Name:** `ECS-agent`
   *   **Launch Type:** `FARGATE` *(Do NOT choose EC2)*
   *   **Network Mode:** `awsvpc`
   *   **Assign Public IP:** `ENABLED`
   *   **Security Group:** Paste your Jenkins Master's Security Group ID.
   *   **Subnets:** Paste your VPC's Subnet IDs.
   *   **Task Definition:** Select the one you made in Step 2.
5. Scroll to **Advanced** -> **Tunnel**: Enter `<Your-Jenkins-Public-IP>:5000`
6. Click **Save**.

### 4. Add AWS Credentials (Strict Naming Rule)
Jenkins needs keys to deploy infrastructure. The ID *must* match the project code exactly.
1. Go to **Manage Jenkins** -> **Credentials** -> **System** -> **Global credentials** -> **Add Credentials**.
2. Select **AWS Credentials**.
3. **ID:** `cdec-alpha-app-aws-creds` *(MUST be exactly this)*
4. **Description:** `cdec-alpha-app-aws-creds`
5. Enter your AWS **Access Key ID** and **Secret Access Key**.
6. Click **Create**.

### 5. Prepare the Custom Worker Docker Image
The default ECS image is blank. We need an image with DevOps tools pre-installed (Docker, kubectl, Terraform, etc.).
1. SSH into your `jenkins-master-server`.
2. Create `vim Dockerfile` and paste the Dockerfile content from the bottom of the [Reference Guide](https://github.com/AnupDudhe/cdec/blob/main/DevOps%20Essentials%20for%20Modern%20Engineering%2FJenkins%2FECS-Node-Containers-Jenkins-Guide.md).
3. Save it. *(In the next phase, you will build this image, push it to ECR, and update the Task Definition from Step 2 to use this new image).*

---

## ✅ Final Setup Checklist
- [ ] Jenkins Master EC2 running on Port 8080.
- [ ] Ports 22, 8080, and 5000 open in Security Group.
- [ ] `devops_stack.sh` executed successfully.
- [ ] ECS Task Execution Role created via `role.sh`.
- [ ] ECS Cloud configured in Jenkins with Tunnel set to `IP:5000`.
- [ ] AWS Credential added in Jenkins with exact ID: `cdec-alpha-app-aws-creds`.
- [ ] Custom Dockerfile created on the server.