# トラブルシューティング

## 🛠️ 既存リソースがある場合の対応（terraform import）

AWS上にすでに同名のリソース（例：セキュリティグループ）が存在していて
`InvalidGroup.Duplicate` などのエラーが出る場合は、**terraform import**コマンドで既存リソースをTerraform管理下に取り込んでください。

### 例：セキュリティグループのインポート

1. AWSコンソールやCLIで既存リソースのIDを調べる
   ```bash
   aws ec2 describe-security-groups --filters Name=group-name,Values=nestjs-hannibal-3-alb-sg Name=vpc-id,Values=<VPC_ID> --query 'SecurityGroups[0].GroupId' --output text
   ```

2. terraform importコマンドでインポート
   ```bash
   cd terraform/backend
   terraform import aws_security_group.alb_sg <セキュリティグループID>
   ```

3. その後、terraform plan/applyを実行

> これにより、既存リソースを削除せずにTerraformで一元管理できるようになります。

## よくあるエラーと解決方法

### Terraform関連
- **InvalidGroup.Duplicate**: 上記のterraform importを実行
- **Backend設定エラー**: `terraform init`を再実行
- **State lock**: 他の操作が実行中の場合は完了を待つ

### AWS CLI関連
- **認証エラー**: AWS認証情報の設定を確認
- **権限不足**: IAMロールの権限を確認
- **リージョン設定**: 正しいリージョン（ap-northeast-1）を指定

### GitHub Actions関連
- **ECR push失敗**: ECRリポジトリが事前作成されているか確認
- **S3 sync失敗**: S3バケットが事前作成されているか確認
- **CloudFront invalidation失敗**: OACが正しく設定されているか確認