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
from diagrams.onprem.ci import GithubActions
from diagrams.onprem.iac import Terraform
import os
import shutil
import re
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
            "fontsize": "16",
            "bgcolor": "white"
        }
    ):
        # DNS & CDN Layer + CI/CD Tools
        dns = Route53("Route53\nhamilcar-hannibal.click")
        github = GithubActions("GitHub Actions")
        terraform = Terraform("Terraform")
        cf = CloudFront("CloudFront")
        
        # Frontend Layer
        s3_frontend = S3("S3 Frontend")
        
        # Load Balancer Layer
        alb = ALB("ALB")
        
        # Container Layer
        with Cluster("ECS Fargate"):
            ecs_service = ECS("ECS Service")
            ecr = ECR("ECR")
        
        # Database Layer
        rds = RDS("RDS PostgreSQL")
        
        # Security & Monitoring
        with Cluster("Security & Monitoring"):
            iam = IAM("IAM")
            logs = Cloudwatch("CloudWatch")
        
        # Network Flow
        dns >> cf
        cf >> s3_frontend
        cf >> alb
        alb >> ecs_service
        ecs_service >> rds
        
        # CI/CD Flow
        ecr >> ecs_service
        
        # Security & Monitoring Flow
        iam >> ecs_service
        ecs_service >> logs
    
    # latest.pngを生成（README.md用）
    shutil.copy(f"{output_dir}/{diagram_name}.png", f"{output_dir}/latest.png")
    
    print(f"✅ AWS構成図を生成しました: {output_dir}/{diagram_name}.png")
    print(f"✅ latest.pngを更新しました: {output_dir}/latest.png")
    return f"{diagram_name}.png"

def update_readme_cache_buster():
    """README.mdのキャッシュバスターをタイムスタンプに自動更新"""
    
    readme_path = "../../README.md"
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    
    try:
        with open(readme_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # キャッシュバスターのパターンを検索・更新
        pattern = r'(docs/architecture/diagrams/latest\.png)(\?v=\d+)?'
        replacement = f'docs/architecture/diagrams/latest.png?v={timestamp}'
        
        updated_content = re.sub(pattern, replacement, content)
        
        with open(readme_path, 'w', encoding='utf-8') as f:
            f.write(updated_content)
        
        print(f"✅ README.mdのキャッシュバスターを更新: ?v={timestamp}")
        return True
        
    except Exception as e:
        print(f"❌ README.md更新エラー: {e}")
        return False

if __name__ == "__main__":
    print("🚀 AWS構成図完全自動化開始...")
    
    try:
        # 1. 構成図生成
        diagram_filename = generate_architecture_diagram()
        
        # 2. README.mdキャッシュバスター自動更新
        update_readme_cache_buster()
        
        print("\n✅ 完全自動化完了！")
        print("次のステップ: git add . && git commit && git push")
        
    except ImportError as e:
        print("❌ エラー: Diagramsライブラリがインストールされていません")
        print("解決方法: pip install diagrams")
        
    except Exception as e:
        print(f"❌ エラーが発生しました: {e}")