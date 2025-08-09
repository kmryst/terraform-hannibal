# Three-tier VPC + ECS Blue/Green Rules

## Objectives
- Migrate from a default VPC single-tier setup to a production-ready three-tier VPC (Presentation/Public, Application/Private, Data/Private) in ap-northeast-1.
- Preserve ECS native Blue/Green deployment (two target groups), ALB listeners for production (80) and test (8080), and existing TG/Listener ARNs where applicable.
- Cost optimization: in dev, use a single NAT Gateway (single AZ); in prod, one NAT per AZ.

## Scope and Deliverables
- New VPC 10.0.0.0/16 with 6 subnets across ap-northeast-1a and 1c:
  - Public: 10.0.1.0/24 (1a), 10.0.2.0/24 (1c)
  - App:    10.0.11.0/24 (1a), 10.0.12.0/24 (1c)
  - Data:   10.0.21.0/24 (1a), 10.0.22.0/24 (1c)
- Internet Gateway, NAT Gateway(s), elastic IP(s), route tables and associations per layer.
- Strict Security Groups for least privilege:
  - ALB → ECS: TCP 3000
  - ECS → RDS: TCP 5432
  - ECS → ECR/CloudWatch/Secrets/SSM: TCP 443 to 0.0.0.0/0
- ECS Fargate tasks in App subnets with assign_public_ip = false.
- RDS in Data subnets with publicly_accessible = false; Multi-AZ toggle via variable.
- Preserve existing Blue/Green setup (two target groups, production/test listeners and listener rules) and use existing ARNs when migrating.

## Naming Conventions
- Prefix all resource names with var.project_name.
  - VPC: ${var.project_name}-vpc
  - Subnets: ${var.project_name}-{layer}-{az-suffix} (e.g., public-1a, app-1c, data-1a)
  - Route tables: ${var.project_name}-{layer}-rt
  - Security groups: ${var.project_name}-{component}-sg
  - ALB: ${var.project_name}-alb
  - ECS Cluster/Service: ${var.project_name}-ecs-cluster / ${var.project_name}-ecs-service
  - RDS SG/DB subnet group: ${var.project_name}-rds-sg / ${var.project_name}-db-subnet-group

## Variables and Defaults
- aws_region: ap-northeast-1 (fixed)
- project_name: nestjs-hannibal-3 (default)
- environment: dev | staging | prod (default: dev)
- vpc_cidr: 10.0.0.0/16 (fixed)
- subnets:
  - public: 10.0.1.0/24 (1a), 10.0.2.0/24 (1c)
  - app:    10.0.11.0/24 (1a), 10.0.12.0/24 (1c)
  - data:   10.0.21.0/24 (1a), 10.0.22.0/24 (1c)
- nat_per_az policy:
  - dev: false (single NAT in 1a)
  - prod: true (NAT per AZ)
- Ports:
  - container_port: 3000
  - alb_listener_port: 80
  - test_listener_port: 8080
- RDS:
  - engine: postgres
  - version/class/name/username/password: reuse existing variables
  - multi_az: controlled by variable (e.g., local.enable_multi_az)
  - publicly_accessible: false
  - backup_retention_period: local.backup_retention_days
  - deletion_protection: local.deletion_protection

## Implementation Policy
1) VPC and Subnets
- Create a new aws_vpc and six aws_subnet resources across 1a/1c with proper tags: Name, project, environment.
- Do not rely on data.aws_vpc.default or data.aws_subnets for the new infra.

2) Internet and NAT
- Attach an Internet Gateway to the VPC.
- NAT Gateways:
  - dev: create a single NAT in a public subnet in 1a (with EIP).
  - prod: create a NAT per AZ (1a and 1c), each in its corresponding public subnet.
- Allocate EIPs for each NAT.

3) Route Tables
- Public route table: default route 0.0.0.0/0 → IGW; associate both public subnets.
- App route tables:
  - dev: both App subnets default route to the single NAT (in 1a).
  - prod: each App subnet routes to its AZ’s NAT.
- Data route tables:
  - No default route to the internet. Local VPC only.
  - Optionally add VPC endpoints (S3, DynamoDB) later to reduce NAT usage.

4) Security Groups (least privilege)
- ALB SG:
  - Ingress: 80, 8080 from 0.0.0.0/0
  - Egress: 3000 to ECS SG (or scope narrowly; avoid wide egress where possible)
- ECS SG:
  - Ingress: 3000 from ALB SG only
  - Egress: 5432 to RDS SG; 443 to 0.0.0.0/0
- RDS SG:
  - Ingress: 5432 from ECS SG only
  - Egress: none (deny by default)

5) ECS Fargate
- network_configuration:
  - subnets: App subnets (both AZs)
  - security_groups: ECS SG
  - assign_public_ip: false
- Keep existing Blue/Green deployment configuration (strategy=BLUE_GREEN, bake time, advanced configuration).
- Preserve existing Target Group and Listener Rule ARNs; adjust only networking and SG references.

6) ALB
- Subnets: Public subnets only.
- SG: ALB SG.
- Listeners: 80 (production), 8080 (test).
- Reuse existing blue/green target groups and listener rules.

7) RDS
- db_subnet_group: use Data subnets (1a/1c).
- publicly_accessible=false, Multi-AZ configurable.
- vpc_security_group_ids=[RDS SG].
- Keep encryption and retention/deletion policies as per existing variables/locals.

8) Availability and Cost
- Multi-AZ across 1a/1c.
- dev: single NAT; prod: NAT per AZ.
- Consider future VPC endpoints for S3/DynamoDB and ECR to minimize NAT traffic.

## Required Code Changes (Terraform)
- Remove data-based default VPC references and create new aws_vpc and subnets.
- Add aws_internet_gateway, aws_eip, aws_nat_gateway, aws_route_table (+ associations).
- Create aws_db_subnet_group for Data subnets.
- Update:
  - aws_lb.subnets → Public subnet IDs
  - aws_ecs_service.network_configuration.subnets → App subnet IDs; assign_public_ip=false
  - RDS db_subnet_group_name → Data aws_db_subnet_group
  - SG rules per least-privilege design

## Non-Functional Requirements
- Tag all resources with Name, project, environment.
- No secrets in VCS; use tfvars/env/Secrets Manager.
- Prepare for WAF on ALB and VPC endpoints.

## Explicit Prohibitions
- No public IPs for ECS tasks.
- RDS must not be publicly accessible.
- No 0.0.0.0/0 routes from Data subnets.
- No excessive 0.0.0.0/0 SG ingress beyond ALB 80/8080.
- Do not place NAT in Data subnets.

## Environment-specific Behaviors
- dev: single NAT in 1a; App subnets route via that NAT.
- prod: NAT per AZ; App subnets route to same-AZ NAT; consider enabling RDS Multi-AZ.

## Outputs
- ALB DNS name
- ECS Cluster/Service names
- ECS Task SG ID
- RDS endpoint and port
- Subnet ID maps per layer
- Route table IDs per layer

## Validation Checklist
- ALB 80/8080 reachable; Blue/Green switch works (test → production).
- ECS tasks have only private IPs; outbound via NAT works (ECR pulls, CloudWatch Logs).
- RDS reachable only from ECS SG on 5432; not public.
- Routes: Public→IGW, App→NAT, Data→local only.
- SGs are least-privilege; no unintended 0.0.0.0/0 ingress.
- RDS Multi-AZ/backup/deletion settings match environment policies.
- Terraform plan shows no destructive changes to existing ALB/TG/Listener ARNs.

## Generation Hints for Amazon Q Developer
- Use for_each and maps for subnets/RT/associations.
- Parameterize NAT count by environment.
- Keep Blue/Green advanced_configuration unchanged; adjust networking and SGs only.
- Emit outputs for key endpoints and IDs.
- Maintain stable names/ARNs; if unavoidable, propose phased cutover.

## Stepwise Order
1) Create VPC, subnets, IGW.
2) Create EIP(s) and NAT(s); set and associate route tables.
3) Create SGs (ALB, ECS, RDS).
4) Create DB subnet group and update RDS.
5) Update ALB subnets.
6) Update ECS networking; keep Blue/Green.
7) plan/apply and validate.
