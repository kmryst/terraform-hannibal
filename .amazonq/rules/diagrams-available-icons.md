# Diagrams Library Available Icons

## 動作確認済み環境
- **diagrams**: 0.24.4
- **Python**: 3.12.0
- **Graphviz**: 13.1.1 (20250719.2154)
- **確認日**: 2025年8月6日
- **動作状況**: ✅ 完全動作確認済み（nestjs-hannibal-3プロジェクト）

## アイコンが正常に動作する理由

### 1. 完全なパッケージインストール
- `pip install diagrams==0.24.4` で**完全版**がインストール
- 以前の問題: PyPI版の不完全なパッケージ
- 現在: 全AWSアイコンファイルが含まれている

### 2. 正しい依存関係
- **Python 3.12.0**: 最新の安定版
- **Graphviz 13.1.1**: アイコン描画エンジンが正常動作
- **依存関係**: graphviz, jinja2, pre-commit すべて解決済み

### 3. パッケージ構造確認済み
```
diagrams/
├── aws/          # AWSアイコン定義（27ファイル）
├── azure/        # Azureアイコン定義
├── gcp/          # GCPアイコン定義
└── ...
```

### 4. 実装で確認済み
- **プロジェクト**: nestjs-hannibal-3
- **生成成功**: AWS構成図（Route53, CloudFront, ALB, ECS, RDS等）
- **出力**: PNG形式で正常生成

## 実際に使用したアイコン例
```python
from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import ECS, ECR
from diagrams.aws.network import ALB, CloudFront, Route53
from diagrams.aws.database import RDS
from diagrams.aws.storage import S3
from diagrams.aws.security import IAM
from diagrams.aws.management import Cloudwatch

with Diagram("NestJS Hannibal 3 Architecture", show=False):
    dns = Route53("Route53")
    cf = CloudFront("CloudFront")
    s3 = S3("S3")
    alb = ALB("ALB")
    ecs = ECS("ECS")
    rds = RDS("RDS")
    iam = IAM("IAM")
    logs = Cloudwatch("CloudWatch")
    
    dns >> cf >> [s3, alb]
    alb >> ecs >> rds
    iam >> ecs >> logs
```

## 制限事項・注意点
- **セキュリティグループ**: 専用アイコンなし（`Nacl`で代用可能）
- **一部新サービス**: Bedrock、IoT Core等は未対応
- ~~**アイコン表示**: PyPI版ではアイコンファイルが含まれない場合あり~~ ✅ **解決済み**

## トラブルシューティング（過去の問題）

### アイコンが表示されない場合
```python
# エラー例
FileNotFoundError: [Errno 2] No such file or directory: 'aws-icons/...'  
```

**解決方法**:
1. **完全再インストール**: `pip uninstall diagrams && pip install diagrams==0.24.4`
2. **Graphviz確認**: `dot -V` でバージョン確認
3. **Python環境**: 3.7+ 推奨（3.12.0で動作確認済み）
4. **依存関係**: `pip show diagrams` で確認

## 代替表現方法
1. **VPC + Subnet**: ネットワーク構成の表現
2. **Nacl**: セキュリティグループの代替
3. **Node**: テキストベースの汎用ノード
4. **Cluster**: 論理グループ化

## 参考リンク
- [Diagrams公式ドキュメント](https://diagrams.mingrammer.com/)
- [AWS Icons一覧](https://diagrams.mingrammer.com/docs/providers/aws)