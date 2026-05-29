# Microservices Template - Cloud Computing

This project serves as a **base template** for developing microservices in Java with Spring Boot, designed for educational purposes in Cloud Computing courses.

** IMPORTANT:** This is an initial template. Students must complete the functionalities according to the course plan, including:
- **Dockerfiles** (Week 2) - Create Dockerfiles for each microservice
- **Docker Compose** (Week 2) - Create docker-compose.yml to orchestrate all services
- Additional unit tests
- CI/CD pipelines (Week 10)
- And other functionalities as per the course plan

**Note:** Students must implement Dockerfiles and complete `docker-compose.yml` as part of Week 2 (see course materials).

## Project Overview

This is a microservices-based application demonstrating a modern cloud-native architecture. The project consists of four main services:

1. **API Gateway** - Single entry point for all client requests using Spring Cloud Gateway
2. **User Service** - Manages user data and operations
3. **Product Service** - Manages product catalog and inventory
4. **Order Service** - Manages orders with inter-service communication (Kafka + OpenFeign)

## Architecture

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│   API Gateway   │  Port: 8080
│ (Spring Gateway)│
└─────┬───────┬───┬───┘
      │       │   │
      ▼       ▼   ▼
┌──────────┐ ┌──────────────┐ ┌──────────────┐
│   User   │ │   Product   │ │    Order    │
│ Service  │ │   Service   │ │   Service   │
│ Port:    │ │ Port:       │ │ Port:       │
│  8081    │ │  8082       │ │  8083       │
└──────────┘ └──────────────┘ └──────────────┘
      ▲              ▲              │
      │              │              │
      └──────────────┴──────────────┘
              OpenFeign (Sync)
      
      ┌──────────────────────────┐
      │        Kafka             │
      │  (Async Event-Driven)    │
      └──────────────────────────┘
```

## Project Structure

```
microservices-project/
├── .github/
│   └── workflows/              # GitHub Actions CI/CD Pipelines
│       ├── terraform-plan.yml  # Validate & plan Terraform on PRs
│       ├── terraform-apply.yml # Apply Terraform infrastructure
│       └── image.yml           # Build & push Docker images
│
├── docs/
│   ├── architecture.md         # System design & VPC/EC2/RDS diagrams
│   ├── deployment.md           # Step-by-step deployment guide
│   └── security.md             # Security model & IAM best practices
│
├── infra/
│   ├── terraform/              # Infrastructure as Code (Terraform)
│   │   ├── main.tf             # Provider & module composition
│   │   ├── variables.tf        # Input variables with validation
│   │   ├── outputs.tf          # Network, compute, database outputs
│   │   ├── backend.tf          # Remote state (S3 + DynamoDB)
│   │   ├── terraform.tfvars.example
│   │   └── modules/
│   │       ├── vpc/            # VPC, subnets, IGW, route tables
│   │       ├── ec2/            # EC2 instance & security groups
│   │       └── rds/            # RDS PostgreSQL & security groups
│   │
│   ├── ansible/                # Configuration Management
│   │   ├── configure-ec2.yml   # Install Docker, Java, build apps
│   │   └── inventory.ini       # EC2 inventory
│
├── services/                   # Microservices (Dockerized)
│   ├── api-gateway/            # API Gateway (Port 8080)
│   │   ├── src/
│   │   ├── Dockerfile          # Multi-stage build
│   │   └── pom.xml
│   ├── product-service/        # Product Service (Port 8082)
│   │   ├── src/
│   │   ├── Dockerfile
│   │   └── pom.xml
│   ├── user-service/           # User Service (Port 8081)
│   │   ├── src/
│   │   ├── Dockerfile
│   │   └── pom.xml
│   └── order-service/          # Order Service (Port 8083)
│       ├── src/
│       ├── Dockerfile
│       └── pom.xml
│
├── docker-compose.yml          # Local dev orchestration
├── Aulas/                       # Course materials
├── README.md                    # This file
└── API_EXAMPLES.md              # API usage examples
```

## Technologies Used

- **Java 21** (LTS) - Programming language
- **Spring Boot 3.4.0** - Application framework (latest stable version)
- **Spring Cloud 2024.0.0** - Latest release train for microservices
- **Spring Cloud Gateway** - API Gateway for routing and load balancing
- **Spring Data JPA** - Data persistence abstraction
- **Spring Kafka** - Asynchronous messaging and event-driven communication
- **OpenFeign** - Declarative HTTP client for synchronous inter-service communication
- **H2 Database** - In-memory database for development
- **Apache Kafka** - Distributed event streaming platform
- **JUnit 5 & Mockito** - Unit testing framework
- **Maven** - Dependency management and build tool
- **Lombok 1.18.34** - Reduces boilerplate code (latest version)
- **Spring Boot Actuator** - Monitoring and health checks
- **Jakarta Validation** - Bean validation framework
- **SpringDoc OpenAPI 2.6.0** - API documentation (Swagger UI)
- **Micrometer & Prometheus** - Metrics collection and observability

## Infrastructure & Cloud Deployment (Weeks 8-12)

### Infrastructure as Code (Terraform)

The project includes complete Terraform configuration for deploying microservices to AWS:

- **VPC Module** (`modules/vpc/`): VPC, public/private subnets across 2 AZs, Internet Gateway, route tables
- **EC2 Module** (`modules/ec2/`): Amazon Linux 2023 instance, security groups with dynamic ports, user data
- **RDS Module** (`modules/rds/`): PostgreSQL database in private subnets, encrypted storage, automated backups

**Key Features:**
- ✅ Input variable validation (CIDR blocks, ports, instance types)
- ✅ Workspace support (dev/staging/prod)
- ✅ Comprehensive tagging strategy
- ✅ S3 remote state backend (optional, shown in `backend.tf`)
- ✅ Outputs for API Gateway routing & application configuration

**Quick Start:**
```bash
cd infra/terraform
terraform init -input=false
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

See [**docs/deployment.md**](docs/deployment.md) for detailed setup.

### Configuration Management (Ansible)

Ansible playbooks automate EC2 setup & application deployment:

- **configure-ec2.yml**: System updates, Docker installation, Java setup, application build
- **inventory.ini**: EC2 host configuration

**Quick Start:**
```bash
cd infra/ansible
ansible-playbook -i inventory.ini configure-ec2.yml
```

### CI/CD Pipelines (GitHub Actions)

Three workflows automate the full pipeline:

1. **terraform-plan.yml**: Triggered on PR, runs format check → validate → plan
2. **terraform-apply.yml**: Manual trigger, applies infrastructure changes
3. **image.yml**: Automatic push to main, builds & pushes Docker images

See `.github/workflows/` for implementation.

### AWS Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     AWS VPC (10.8.0.0/16)                   │
│                                                              │
│  Public Subnets (AZ-a, AZ-b)                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  EC2 Instance (AL2023, t3.micro)                     │  │
│  │  ├─ Docker: API Gateway (8080)                       │  │
│  │  ├─ Docker: Product Service (8082)                   │  │
│  │  ├─ Docker: User Service (8081)                      │  │
│  │  └─ Docker: Order Service (8083)                     │  │
│  └──────────────────────────────────────────────────────┘  │
│  ↓ (Port 5432, App SG)                                      │
│  Private Subnets (AZ-a, AZ-b)                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  RDS PostgreSQL (db.t3.micro)                        │  │
│  │  └─ cloudprojectdb (replica-ready, automated backup) │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  Internet Gateway → Route 0.0.0.0/0                         │
└─────────────────────────────────────────────────────────────┘
```



Before running this project, ensure you have the following installed:

- **Java 21** (LTS) - **Required**
  - Check installation: `java -version`
  - **Important:** This project requires Java 21. Java 25+ may have compatibility issues with Lombok.
  - Download from: [Oracle JDK](https://www.oracle.com/java/technologies/downloads/) or [OpenJDK](https://openjdk.org/)
  - On macOS, you can install via Homebrew: `brew install openjdk@21`
  - Set JAVA_HOME: `export JAVA_HOME=$(/usr/libexec/java_home -v 21)`
- **Maven 3.8+**
  - Check installation: `mvn -version`
  - Download from: [Apache Maven](https://maven.apache.org/download.cgi)
- **Git**
  - Check installation: `git --version`
  - Download from: [Git](https://git-scm.com/downloads)
- **Docker** (Optional, for running Kafka and services via docker-compose)
  - Check installation: `docker --version`
  - Download from: [Docker](https://www.docker.com/get-started)
- **IDE** (Recommended: IntelliJ IDEA, Eclipse, or VS Code)
  - **Note:** If using IntelliJ IDEA, ensure Lombok plugin is installed and annotation processing is enabled

## How to Run Locally

### Option 1: Run Each Service Separately

Open three separate terminal windows:

**Terminal 1 - User Service:**
```bash
cd user-service
mvn spring-boot:run
```

**Terminal 2 - Product Service:**
```bash
cd product-service
mvn spring-boot:run
```

**Terminal 3 - Order Service:**
```bash
cd order-service
mvn spring-boot:run
```

**Terminal 4 - API Gateway:**
```bash
cd api-gateway
mvn spring-boot:run
```

**Important:** Before starting the services, **Kafka must be running**. Otherwise you will see errors like *"Node 1 disconnected"* or *"Connection to node 1 (localhost:9092) could not be established"*. To start only Kafka and Zookeeper (recommended for local development):
```bash
docker-compose -f docker-compose.yml up -d
# Wait a few seconds for Kafka to be ready, then start the services
```

### Option 2: Build and Run JAR Files

```bash
# Build all services
mvn clean package

# Run User Service
cd user-service
java -jar target/user-service-1.0.0.jar

# Run Product Service (in another terminal)
cd product-service
java -jar target/product-service-1.0.0.jar

# Run API Gateway (in another terminal)
cd api-gateway
java -jar target/api-gateway-1.0.0.jar
```

### Service Endpoints

Once all services are running, they will be available at:

- **API Gateway**: http://localhost:8080
- **User Service**: http://localhost:8081
- **Product Service**: http://localhost:8082
- **Order Service**: http://localhost:8083

**Kafka** should be running on:
- **Kafka Broker**: localhost:9092
- **Zookeeper**: localhost:2181

## API Endpoints

### API Gateway (Port 8080)

All requests should go through the API Gateway:

- `GET /api/users` - List all users
- `GET /api/users/{id}` - Get user by ID
- `POST /api/users` - Create new user
- `PUT /api/users/{id}` - Update user
- `DELETE /api/users/{id}` - Delete user
- `GET /api/products` - List all products
- `GET /api/products/{id}` - Get product by ID
- `POST /api/products` - Create new product
- `PUT /api/products/{id}` - Update product
- `DELETE /api/products/{id}` - Delete product
- `GET /api/orders` - List all orders
- `GET /api/orders/{id}` - Get order by ID
- `GET /api/orders/user/{userId}` - Get orders by user ID
- `POST /api/orders` - Create new order
- `PUT /api/orders/{id}/status` - Update order status

### User Service (Port 8081)

Direct access to User Service (bypassing gateway):

- `GET /users` - List all users
- `GET /users/{id}` - Get user by ID
- `POST /users` - Create new user
- `PUT /users/{id}` - Update user
- `DELETE /users/{id}` - Delete user

### Product Service (Port 8082)

Direct access to Product Service (bypassing gateway):

- `GET /products` - List all products
- `GET /products/{id}` - Get product by ID
- `POST /products` - Create new product
- `PUT /products/{id}` - Update product
- `DELETE /products/{id}` - Delete product

### Order Service (Port 8083)

Direct access to Order Service (bypassing gateway):

- `GET /orders` - List all orders
- `GET /orders/{id}` - Get order by ID
- `GET /orders/user/{userId}` - Get orders by user ID
- `POST /orders` - Create new order
- `PUT /orders/{id}/status?status={status}` - Update order status

## Running Tests

Execute tests for each service:

```bash
# Set Java 21 (if not default)
export JAVA_HOME=$(/usr/libexec/java_home -v 21)

# Run User Service tests
cd user-service
mvn test

# Run Product Service tests
cd product-service
mvn test

# Run Order Service tests
cd order-service
mvn test

# Run API Gateway tests
cd api-gateway
mvn test

# Run all tests from root
mvn test -pl user-service,product-service,order-service,api-gateway
```

### Test Coverage

The project uses **JaCoCo** for coverage. Each module enforces a minimum line coverage (85% for services, 70% for API Gateway). After running `mvn test`, open the report at `target/site/jacoco/index.html` in each module.

- **User Service**: Controller tests (CRUD + validation + exception handler), Service tests (all branches including email-in-use), GlobalExceptionHandler, Application context
- **Product Service**: Controller tests (CRUD + search + exception handler), Service tests (including null stockQuantity branches), OrderEventConsumer (success, product not found, insufficient stock, multiple items, save failure), GlobalExceptionHandler, Application context
- **Order Service**: Controller tests (create, validation, get by id, exception handler), Service tests (create/get/update, user/product not found, insufficient stock), GlobalExceptionHandler, Order model (addOrderItem, calculateTotal), Application context
- **API Gateway**: Application context (loads GatewayConfig)

All tests use:
- **JUnit 5** for test framework
- **Mockito** for mocking dependencies
- **Spring Boot Test** for integration tests
- **JaCoCo** for coverage reports and minimum coverage checks
- **MockMvc** for controller testing
- **Spring Kafka Test** for Kafka integration testing

### Best Practices Implemented

- ✅ **OpenAPI/Swagger Documentation** - Complete API documentation for all services
- ✅ **Observability** - Prometheus metrics via Actuator
- ✅ **Comprehensive Testing** - Unit and integration tests with high coverage
- ✅ **Error Handling** - Global exception handlers with proper HTTP status codes
- ✅ **Validation** - Jakarta Validation for request validation
- ✅ **Modern Dependencies** - Latest stable versions of all frameworks
- ✅ **API Gateway** - Centralized routing with order service support

## Inter-Service Communication

This project demonstrates two types of inter-service communication:

### 1. Synchronous Communication (OpenFeign)

**Order Service** uses OpenFeign to make synchronous HTTP calls to:
- **User Service** - Validates user existence before creating orders
- **Product Service** - Validates products and fetches product details

**Example Flow:**
```
Order Service → (OpenFeign) → User Service: Validate user
Order Service → (OpenFeign) → Product Service: Validate products & get details
Order Service: Create order
```

### 2. Asynchronous Communication (Kafka)

**Order Service** publishes events to Kafka topics:
- `order-created` - Published when a new order is created
- `order-status-changed` - Published when order status changes

**Product Service** consumes events from Kafka:
- Listens to `order-created` topic to update inventory

**Example Flow:**
```
Order Service: Creates order → Publishes OrderCreatedEvent to Kafka
Product Service: Consumes event → Updates product inventory
```

### 3. Optional Amazon SQS (Week 10 – cloud lab)

The template also includes **optional AWS SQS** wiring for a shared **`product-events`** queue:

- **product-service** publishes a JSON `ProductCreated` event after a successful **`POST /products`** when `cloud.sqs.product-events.enabled=true`.
- **order-service** long-polls the same queue URL and logs received events when `cloud.sqs.product-events-consumer.enabled=true`.

Terraform for queues + DLQ lives in **`infra/week9-sqs/`**. The Week 10 course materials focus on **infrastructure** (queues, IAM, environment variables), not on implementing Java producers or consumers.

## Microservice Architecture

Each microservice follows a layered architecture pattern:

```
┌─────────────────────┐
│   Controller Layer  │  REST API endpoints
├─────────────────────┤
│   Service Layer     │  Business logic
├─────────────────────┤
│  Repository Layer   │  Data access
├─────────────────────┤
│    Model Layer      │  Entity/Domain models
└─────────────────────┘
```

### Layer Responsibilities

1. **Controller Layer** - Handles HTTP requests/responses, input validation
2. **Service Layer** - Contains business logic, transaction management
3. **Repository Layer** - Data access abstraction, database operations
4. **Model Layer** - Entity classes representing database tables
5. **DTO Layer** - Data Transfer Objects for API communication

## Course Tasks by Week

### Week 2 - Docker and Dockerfile
- [ ] Create Dockerfile for each microservice
- [ ] Create docker-compose.yml for local orchestration
- [ ] Test execution with Docker Compose
- [ ] Implement multi-stage builds for optimization

### Week 3 - DockerHub
- [ ] Build Docker images
- [ ] Push to DockerHub or institutional repository
- [ ] Pull and execute in another environment
- [ ] Tag images with version numbers

### Week 4 - AWS CLI
- [ ] Configure AWS CLI
- [ ] Create automation scripts
- [ ] Test AWS service interactions

### Week 5 - AWS Networking
- [ ] Create VPC and subnets
- [ ] Configure route tables
- [ ] Set up security groups
- [ ] Configure internet gateway

### Week 6 - EC2
- [ ] Create EC2 instance
- [ ] Manual container deployment on EC2
- [ ] Configure security groups for services
- [ ] Test remote access

### Week 7 - Cloud Databases
- [ ] Replace H2 with AWS RDS
- [ ] Configure remote database connection
- [ ] Update connection strings
- [ ] Test database connectivity

### Week 8-9 - Terraform
- [ ] Create infrastructure with Terraform
- [ ] Modularize Terraform code
- [ ] Implement state management
- [ ] Create reusable modules

### Week 10 - CI/CD
- [ ] Create GitHub Actions pipeline
- [ ] Implement automated deployment
- [ ] Add automated testing
- [ ] Configure deployment environments

### Week 11 - SQS (event-driven architecture, cloud focus)
- [ ] Create SQS main queue and DLQ (Terraform in `infra/week9-sqs/`, or Console / CLI)
- [ ] Configure redrive policy and sensible visibility timeout / long polling
- [ ] Grant IAM least privilege (`SendMessage` / `ReceiveMessage` / `DeleteMessage`, etc.)
- [ ] Enable the template via `CLOUD_SQS_*` environment variables and verify logs end-to-end

### Week 12 - Ansible
- [ ] Create Ansible playbooks
- [ ] Automate configuration management
- [ ] Implement infrastructure provisioning
- [ ] Configure application deployment

## API Usage Examples

See **[API_EXAMPLES.md](API_EXAMPLES.md)** for practical API usage examples with curl commands and request/response samples.

## Important Notes

1. **Java Version**: **This project requires Java 21 (LTS)**. Java 25+ has compatibility issues with Lombok. See [COMPILATION.md](COMPILATION.md) for details.
2. **Database**: Currently uses H2 in-memory database. Should be replaced with AWS RDS in Week 7.
3. **Docker (Week 2)**: 
   - **Students must create Dockerfiles** for each service (user-service, product-service, order-service, api-gateway)
   - **Students must complete docker-compose.yml** in the project root (TODO structure is provided)
   - See `Aulas/Week-02/` for detailed instructions
4. **Tests**: Comprehensive unit tests are included (44+ test methods). All tests pass with Java 21.
5. **CI/CD**: Pipelines must be created by students in Week 10.
6. **Kafka**: Required for Order Service. Students will configure this in docker-compose.yml (Week 2).
7. **Inter-Service Communication**: 
   - **Synchronous**: OpenFeign (Order Service → User/Product Services)
   - **Asynchronous**: Kafka (Order Service publishes events, Product Service consumes)
3. **Tests**: Basic tests are included as examples. Students should expand test coverage.
4. **CI/CD**: Pipelines must be created by students in Week 10.
5. **Configuration**: Service URLs are hardcoded for local development. Will be updated when Docker Compose is implemented.

## Health Checks & Observability

Spring Boot Actuator is configured for health monitoring and observability:

### Health Endpoints
- **User Service**: http://localhost:8081/actuator/health
- **Product Service**: http://localhost:8082/actuator/health
- **Order Service**: http://localhost:8083/actuator/health
- **API Gateway**: http://localhost:8080/actuator/health

### Metrics (Prometheus)
- **User Service**: http://localhost:8081/actuator/prometheus
- **Product Service**: http://localhost:8082/actuator/prometheus
- **Order Service**: http://localhost:8083/actuator/prometheus
- **API Gateway**: http://localhost:8080/actuator/prometheus

### API Documentation (Swagger UI)
- **User Service**: http://localhost:8081/swagger-ui.html
- **Product Service**: http://localhost:8082/swagger-ui.html
- **Order Service**: http://localhost:8083/swagger-ui.html
- **API Gateway**: http://localhost:8080/swagger-ui.html

### OpenAPI JSON
- **User Service**: http://localhost:8081/api-docs
- **Product Service**: http://localhost:8082/api-docs
- **Order Service**: http://localhost:8083/api-docs
- **API Gateway**: http://localhost:8080/api-docs

## Development Guidelines

### Code Style
- Follow Java naming conventions
- Use meaningful variable and method names
- Add Javadoc comments for public methods
- Keep methods focused and single-purpose

### Testing
- Write unit tests for service layer
- Write integration tests for controllers
- Aim for at least 70% code coverage
- Use meaningful test method names

### Error Handling
- Use appropriate HTTP status codes
- Provide meaningful error messages
- Log errors appropriately
- Handle exceptions gracefully

## Running with Docker Compose

**⚠️ IMPORTANT:** Students must complete the `docker-compose.yml` file and create Dockerfiles for each service as part of Week 2 exercises.

Once you've completed `docker-compose.yml` and built images from your Dockerfiles:

```bash
# Start all services (Kafka, Zookeeper, and all microservices)
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down
```

**Note:** 
- Make sure Docker is installed and running
- You must create Dockerfiles for each service first (Week 2)
- See `Aulas/Week-02/` for detailed instructions

## Troubleshooting

### "Node 1 disconnected" / "Connection to node 1 (localhost:9092) could not be established"
This means **Kafka is not running** or not reachable. The application (order-service, product-service) expects a Kafka broker at `localhost:9092`.

**Solution:**
1. Start Kafka and Zookeeper with Docker:
   ```bash
   docker-compose -f docker-compose.yml up -d
   ```
2. Wait 10–20 seconds for Kafka to be ready, then start the microservices.
3. If you still see the error, check that Kafka is running and that port 9092 is free:
   ```bash
   docker ps | grep kafka
   # Kafka should be listening on 0.0.0.0:9092
   ```

### Bootstrap servers: use `localhost:9092`, not `kafka:9092`
If you set `spring.kafka.bootstrap-servers` to **kafka:9092**, the app can only connect when it runs **inside Docker** (same network as the Kafka container). The hostname `kafka` does not exist on your machine.

- **Running with Maven** (`mvn spring-boot:run`): use **localhost:9092** in `application.yml` (product-service, order-service). Start Kafka with `docker-compose -f docker-compose.kafka.yml up -d`.
- **Running everything in Docker** (e.g. your Week 2 docker-compose): then use **kafka:9092** (or set `SPRING_KAFKA_BOOTSTRAP_SERVERS=kafka:9092` in the container environment).

The project defaults are `localhost:9092` so that local development with Maven works.

### Other Kafka connection issues
If services cannot connect to Kafka:
```bash
# Check if Kafka is running
docker ps | grep kafka

# Check Kafka logs
docker-compose -f docker-compose.yml logs kafka

# Verify Kafka is accessible (optional)
telnet localhost 9092
```

### Port Already in Use
If you get a "port already in use" error:
```bash
# Find process using port
lsof -i :8080  # or 8081, 8082

# Kill process
kill -9 <PID>
```

### Database Connection Issues
- Ensure H2 is properly configured in application.yml
- Check database URL and credentials
- Verify Spring Data JPA is properly configured

### Service Communication Issues
- Verify all services are running
- Check API Gateway routing configuration
- Verify service URLs in GatewayConfig.java

## Contributing

This is an educational template. Students should complete functionalities according to the course plan.

## License

This project is for educational purposes.

## GitHub Actions Workflows

### terraform-plan.yml

**Trigger:** PR on paths `infra/terraform/**`

**Steps:**
1. Checkout repository
2. Configure AWS credentials (OIDC)
3. Format check (`terraform fmt -check`)
4. Validate syntax (`terraform validate`)
5. Plan infrastructure (`terraform plan`)
6. Comment plan on PR

**Required GitHub Secrets:**
- `AWS_ROLE_TO_ASSUME` — OIDC role ARN

### terraform-apply.yml

**Trigger:** Manual (`workflow_dispatch`)

**Steps:**
1. Checkout repository
2. Configure AWS credentials (OIDC)
3. Initialize Terraform
4. Apply infrastructure (`terraform apply -auto-approve`)

**Required GitHub Secrets:**
- `AWS_ROLE_TO_ASSUME`
- `TF_KEY_NAME`
- `DB_PASSWORD`

### image.yml

**Trigger:** Push to `main`

**Steps:**
1. Build Docker image (product-service)
2. Push to DockerHub

**Required GitHub Secrets:**
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

## Documentation

- **[docs/architecture.md](docs/architecture.md)** — VPC layout, data flow, service interaction
- **[docs/deployment.md](docs/deployment.md)** — Step-by-step deployment guide, prerequisites, troubleshooting
- **[docs/security.md](docs/security.md)** — Security model, IAM, secrets management, production hardening
- **[infra/terraform/README.md](infra/terraform/README.md)** — Terraform modules overview

## Additional Resources

- [Spring Boot Documentation](https://spring.io/projects/spring-boot)
- [Spring Cloud Gateway Documentation](https://spring.io/projects/spring-cloud-gateway)
- [Spring Data JPA Documentation](https://spring.io/projects/spring-data-jpa)
- [Microservices Patterns](https://microservices.io/patterns/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [Ansible AWS Modules](https://docs.ansible.com/ansible/latest/collections/amazon/aws/index.html)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [Course Materials](Aulas/README.md)
