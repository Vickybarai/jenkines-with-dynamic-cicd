# Backend

Three Spring Boot microservices for the CDEC Alpha platform.

| Service | Port | API base path | Directory |
|---------|------|---------------|-----------|
| [auth-service](auth-service/README.md) | 8081 | `/api/auth` | User registration, login, JWT |
| [course-service](course-service/README.md) | 8082 | `/api/courses` | Course catalog |
| [enrollment-service](enrollment-service/README.md) | 8083 | `/api/enroll` | Course enrollments |

## Stack

| Tool | Version |
|------|---------|
| Java | 17 |
| Spring Boot | 3.2.0 |
| Maven | 3.9.6 (via `./mvnw` wrapper) |
| MongoDB | Atlas (remote) |

## Prerequisites

```bash
java --version    # should print 17.x
./mvnw --version  # run from any service directory
```

For deployment, also install Docker, AWS CLI, and kubectl:

```bash
docker --version
aws --version
kubectl version --client
```

## Run all services locally

Each service runs in its own terminal. MongoDB connection defaults are in each service's `application.yml`; override with `MONGO_URI` if needed.

```bash
# Terminal 1 — auth
cd application/backend/auth-service
./mvnw spring-boot:run

# Terminal 2 — courses
cd application/backend/course-service
./mvnw spring-boot:run

# Terminal 3 — enrollments
cd application/backend/enrollment-service
./mvnw spring-boot:run
```

Health checks:

```bash
curl http://localhost:8081/api/auth/health
curl http://localhost:8082/api/courses/health
curl http://localhost:8083/api/enroll/health
```

## Shared environment variables

| Variable | Used by | Description |
|----------|---------|-------------|
| `MONGO_URI` | All services | MongoDB connection string |
| `JWT_SECRET` | auth-service, enrollment-service | Shared secret for JWT signing and validation |

## Build and deploy

Each service has its own README with build and deploy steps:

- [auth-service](auth-service/README.md)
- [course-service](course-service/README.md)
- [enrollment-service](enrollment-service/README.md)

Production deployment flow (per service):

1. Build the JAR with Maven
2. Build a Docker image and push to ECR
3. Roll out to Kubernetes (EKS)
