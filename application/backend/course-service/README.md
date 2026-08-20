# Course Service

Course catalog microservice — list, create, update, and delete courses.

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
cd application/backend/course-service
chmod +x mvnw
```

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MONGO_URI` | Set in `application.yml` | MongoDB connection string |

For production:

```bash
export MONGO_URI="mongodb+srv://user:pass@cluster.mongodb.net/cb_auth"
```

## Run locally (development)

```bash
./mvnw spring-boot:run
```

Service starts on [http://localhost:8082](http://localhost:8082).

API base path: `/api/courses`

```bash
curl http://localhost:8082/api/courses/health
curl http://localhost:8082/api/courses/
```

## Build

### Development

No separate build step — use `./mvnw spring-boot:run` for local development.

### Production

Build the executable JAR:

```bash
./mvnw clean package -DskipTests
```

Output: `target/course-service-1.0.0.jar`

Run the JAR:

```bash
export MONGO_URI="mongodb+srv://user:pass@cluster.mongodb.net/cb_auth"

java -jar target/course-service-1.0.0.jar
```

## Deploy to EKS

Build, containerize, push to ECR, and roll out to Kubernetes.

Replace placeholders with your values:

```bash
cd application/backend/course-service

ECR_REGISTRY=YOUR_ACCOUNT.dkr.ecr.eu-west-1.amazonaws.com
IMAGE=${ECR_REGISTRY}/cloudblitz/course-service:latest
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
kubectl rollout status deployment/course-service -n ${KUBE_NAMESPACE} --timeout=300s
```

## Other commands

```bash
./mvnw test              # run unit tests
./mvnw clean package     # build with tests
```

## Project structure

```text
course-service/
├── src/main/java/       # Application code
├── src/main/resources/
│   └── application.yml  # Port and MongoDB config
├── pom.xml
├── mvnw                 # Maven wrapper
└── target/              # Build output (created by mvnw package)
```
