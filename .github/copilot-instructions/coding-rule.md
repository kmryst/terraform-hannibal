## 🔑 コーディング規約

### TypeScript/NestJS
- **ファイル命名**: kebab-case (`route.service.ts`)
- **クラス名**: PascalCase (`RouteService`)
- **デコレータ**: `@Module()`, `@Resolver()`, `@Query()`
- **GraphQL Code First**: Resolver優先、Schema自動生成

### Terraform
- **ファイル命名**: kebab-case (`ecs-fargate.tf`)
- **リソース名**: スネークケース (`aws_ecs_service.main`)
- **変数名**: スネークケース (`enable_blue_green`)
- **モジュール**: `modules/` 配下で再利用可能に設計

### Git Commit
**Conventional Commits**:
```
feat: GraphQL Resolverに新エンドポイント追加
fix: ECS Task Definition のメモリ設定修正
docs: README.md にデプロイ手順追記
infra: Terraform に CloudWatch Alarm追加
```

---
