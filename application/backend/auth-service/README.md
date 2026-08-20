# Auth Service

Authentication microservice — user registration, login, and JWT token issuance.

## Stack

| Tool | Version |
|------|---------|
| Java | 17 |
| Spring Boot | 3.2.0 |
| Maven | 3.9.6 (via `./mvnw`) |
| MongoDB | Atlas |

## Prerequisites

```bash
java --version    # should print 17.x
```

## Setup

```bash
cd application/backend/auth-service
chmod +x mvnw
```

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MONGO_URI` | Set in `application.yml` | MongoDB connection string |
| `JWT_SECRET` | Set in `application.yml` | Secret key for JWT signing |

For production, always set these explicitly:

```bash
export MONGO_URI="mongodb+srv://user:pass@cluster.mongodb.net/cb_auth"
export JWT_SECRET="your-production-secret"
```

## Run locally (development)

```bash
./mvnw spring-boot:run
```

Service starts on [http://localhost:8081](http://localhost:8081).

API base path: `/api/auth`

```bash
curl http://localhost:8081/api/auth/health
```

## Build

### Development

No separate build step — use `./mvnw spring-boot:run` for local development.

### Production

Build the executable JAR:

```bash
./mvnw clean package -DskipTests
```

Output: `target/auth-service-1.0.0.jar`

Run the JAR:

```bash
export MONGO_URI="mongodb+srv://user:pass@cluster.mongodb.net/cb_auth"
export JWT_SECRET="your-production-secret"

java -jar target/auth-service-1.0.0.jar
```

## Deploy to EKS

Build, containerize, push to ECR, and roll out to Kubernetes.

Replace placeholders with your values:

```bash
cd application/backend/auth-service

ECR_REGISTRY=YOUR_ACCOUNT.dkr.ecr.eu-west-1.amazonaws.com
IMAGE=${ECR_REGISTRY}/cloudblitz/auth-service:latest
EKS_CLUSTER=YOUR_CLUSTER_NAME
EKS_REGION=eu-west-1
KUBE_NAMESPACE=cloudblitz

# Build JAR
./mvnw clean package -DskipTests

# Build and push Docker image
aws ecr get-login-password --region eu-west-1 | \
  docker login --username AWS --password-stdin ${ECR_REGISTRY}

docker build -t ${IMAGE} .
docker push ${IMAGE}

# Deploy to EKS
aws eks update-kubeconfig --region ${EKS_REGION} --name ${EKS_CLUSTER}
kubectl apply -f k8s/ -n ${KUBE_NAMESPACE}
kubectl rollout status deployment/auth-service -n ${KUBE_NAMESPACE} --timeout=300s
```

## Other commands

```bash
./mvnw test              # run unit tests
./mvnw clean package     # build with tests
```

## Project structure

```text
auth-service/
├── src/main/java/       # Application code
├── src/main/resources/
│   └── application.yml  # Port, MongoDB, JWT config
├── pom.xml
├── mvnw                 # Maven wrapper
└── target/              # Build output (created by mvnw package)
```
