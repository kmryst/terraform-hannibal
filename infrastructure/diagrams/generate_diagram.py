#!/usr/bin/env python3
"""
NestJS Hannibal 3 Architecture Diagram Generator
AWS構成図を自動生成するスクリプト
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import ECS
from diagrams.aws.network import ALB, CloudFront, Route53
from diagrams.aws.database import RDS
from diagrams.aws.storage import S3

from diagrams.aws.security import IAM, SecurityGroup
from diagrams.aws.management import Cloudwatch

def generate_architecture_diagram():
    """NestJS Hannibal 3のAWS構成図を生成"""
    
    with Diagram(
        "NestJS Hannibal 3 Architecture", 
        show=False, 
        filename="docs/architecture",
        outformat="svg",
        direction="TB"
    ):
        # DNS & Domain
        dns = Route53("hamilcar-hannibal.click")
        
        # Frontend & CDN
        with Cluster("Frontend & CDN"):
            cf = CloudFront("CloudFront Distribution")
            s3_frontend = S3("Static Files\n(React App)")
        
        # Application Layer
        with Cluster("Application Layer"):
            alb = ALB("Application\nLoad Balancer")
            
            with Cluster("ECS Fargate Cluster"):
                ecs_service = ECS("API Service\n(NestJS)")

        
        # Database Layer
        with Cluster("Database Layer"):
            rds = RDS("PostgreSQL\nDatabase")
        
        # Security & Monitoring
        with Cluster("Security & Monitoring"):
            sg_alb = SecurityGroup("ALB\nSecurity Group")
            sg_ecs = SecurityGroup("ECS\nSecurity Group")
            sg_rds = SecurityGroup("RDS\nSecurity Group")
            iam_role = IAM("ECS Task\nExecution Role")
            logs = Cloudwatch("CloudWatch\nLogs")
        
        # Connection flows
        dns >> cf
        cf >> Edge(label="Static Files\n(/, /assets/*)") >> s3_frontend
        cf >> Edge(label="API Requests\n(/api/*)") >> alb
        
        alb >> ecs_service
        ecs_service >> rds

        
        # Security relationships
        sg_alb >> Edge(style="dashed", color="orange") >> alb
        sg_ecs >> Edge(style="dashed", color="orange") >> ecs_service
        sg_rds >> Edge(style="dashed", color="orange") >> rds
        iam_role >> Edge(style="dashed", color="blue") >> ecs_service
        ecs_service >> Edge(style="dashed", color="green") >> logs

if __name__ == "__main__":
    print("Generating NestJS Hannibal 3 architecture diagram...")
    generate_architecture_diagram()
    print("✅ Architecture diagram generated: docs/architecture.svg")