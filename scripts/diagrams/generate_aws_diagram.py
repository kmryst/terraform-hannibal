#!/usr/bin/env python3
"""
NestJS Hannibal 3 AWS Architecture Diagram Generator
Diagrams（Python）を使用してAWS構成図を自動生成
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import ECS, ECR
from diagrams.aws.network import ALB, CloudFront, Route53
from diagrams.aws.database import RDS
from diagrams.aws.storage import S3
from diagrams.aws.security import IAM
from diagrams.aws.management import Cloudwatch
import os
import shutil
from datetime import datetime

def generate_architecture_diagram():
    """NestJS Hannibal 3のAWSアーキテクチャ図を生成"""
    
    # 出力ディレクトリ設定
    output_dir = "../../docs/architecture/diagrams"
    os.makedirs(output_dir, exist_ok=True)
    
    # 図のファイル名（タイムスタンプ付き）
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    diagram_name = f"nestjs-hannibal-3-architecture-{timestamp}"
    
    with Diagram(
        "AWS Architecture",
        filename=f"{output_dir}/{diagram_name}",
        show=False,
        direction="TB",
        graph_attr={
            "fontsize": "12",
            "bgcolor": "white",
            "size": "10,5",
            "dpi": "150",
            "margin": "0.2",
            "pad": "0.2"
        }
    ):
        # DNS & CDN Layer
        dns = Route53("Route53\nhamilcar-hannibal.click")
        cf = CloudFront("CloudFront\nGlobal CDN")
        
        # Frontend Layer
        s3_frontend = S3("S3 Frontend")
        
        # Load Balancer Layer
        alb = ALB("Application Load Balancer\nBlue/Green Support")
        
        # Container Layer
        with Cluster("ECS Fargate Cluster"):
            ecs_service = ECS("ECS Service\nBlue/Green Deployment")
            ecr = ECR("ECR Repository")
        
        # Database Layer
        rds = RDS("RDS PostgreSQL")
        
        # Security & Monitoring
        with Cluster("Security & Monitoring"):
            iam = IAM("IAM Roles\nPermission Boundary")
            logs = Cloudwatch("CloudWatch Logs\nECS Task Logs")
        
        # Network Flow
        dns >> cf
        cf >> Edge(label="Static Files") >> s3_frontend
        cf >> Edge(label="/api/*") >> alb
        alb >> Edge(label="Blue/Green") >> ecs_service
        ecs_service >> Edge(label="GraphQL API") >> rds
        
        # CI/CD Flow
        ecr >> Edge(label="Container Images") >> ecs_service
        
        # Security & Monitoring Flow
        iam >> Edge(label="Permissions") >> ecs_service
        ecs_service >> Edge(label="Logs") >> logs
    
    # 固定名でもコピー（README.md用）
    shutil.copy(f"{output_dir}/{diagram_name}.png", f"{output_dir}/latest.png")
    
    print(f"✅ AWS構成図を生成しました: {output_dir}/{diagram_name}.png")
    print(f"✅ 固定名でもコピー: {output_dir}/latest.png")
    return f"{diagram_name}.png"

if __name__ == "__main__":
    print("🚀 NestJS Hannibal 3 AWS構成図生成開始...")
    
    try:
        diagram_filename = generate_architecture_diagram()
        print("✅ 構成図生成完了！")
        
    except ImportError as e:
        print("❌ エラー: Diagramsライブラリがインストールされていません")
        print("解決方法: pip install diagrams")
        
    except Exception as e:
        print(f"❌ エラーが発生しました: {e}")