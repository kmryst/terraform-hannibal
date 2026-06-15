# Dependency Management

`terraform-hannibal` の npm 依存関係を、安全性・互換性・変更範囲のバランスを取りながら更新するための運用方針です。

## 基本方針

- root は NestJS backend、`client/` は React frontend として、manifest・lockfile・audit を別々に管理する
- security / compatibility 対応では、選択した supported line の最新 stable を採用する
- prerelease や、修正に無関係な major update は同じ PR に混ぜない
- direct dependency はこの repository が version 選択と検証を担う
- transitive dependency は上流 package が owner だが、lockfile、advisory、runtime verification はこの repository でも確認する
- lockfile は削除して全面再生成せず、対象 package を段階的に更新して差分を review する
- `npm audit fix --force` は使用しない

## 更新手順

1. 更新前に root / client で `npm ci`、build、test、audit を実行する
2. 競合する旧 package と削除対象を `npm uninstall --no-audit` で外す
3. direct dependency を version 付きの `npm install --no-audit` で追加する
4. dev dependency は `npm install --no-audit --save-dev` で更新する
5. direct dependency の選択版と audit 結果を確認する
6. `npm audit fix --package-lock-only` を実行し、direct dependency が意図せず変わっていないことを確認する
7. `node_modules` を削除し、`npm ci` だけで再構築する
8. lint、build、unit test、E2E、Docker build、`npm ls --all`、`npm audit` を確認する

## 現行 Backend Contract

Node.js は `>=24 <25` を application runtime / CI / container の support contract とします。`package.json` の `engines` は開発者への宣言であり、実行 version は `node:24-alpine` と GitHub Actions の `actions/setup-node` で固定します。

| 領域 | 採用 version | 用途・制約 | 再検討条件 |
|---|---:|---|---|
| NestJS core / common / platform / testing | `11.1.26` | NestJS 11系列を同一patchへ統一する | NestJS 12 stable と周辺moduleの対応後 |
| NestJS GraphQL / Apollo | `13.4.2` | NestJS 11、GraphQL 16、Apollo Server 5の統合 | 14系stable、またはPlayground依存除去時 |
| Apollo Server | `5.5.1` | Apollo Server 4 EOL後のsupported line | 6系stableとNestJS対応後 |
| Express integration | `@as-integrations/express5@1.1.2` | Nest Apollo 13がruntimeで直接loadする | Nest Apolloのdependency宣言変更時 |
| GraphQL.js | `16.14.2` | Apollo/Nestのsupported stable major | GraphQL 17 stableと全peer対応後 |
| TypeORM | `0.3.30` | 既知脆弱性を解消し、breaking migrationを分離する | TypeORM 1.0移行Issueで再評価 |
| Node.js types | `24.13.2` | runtime majorと型定義majorを一致させる | Node runtime major更新時 |

`@nestjs/config@4.0.4`、`@nestjs/typeorm@11.0.1`、`@nestjs/schematics@11.1.0`、`ts-morph@20.0.0` も上記contractに合わせます。`@nestjs/cli@11.0.23`、TypeScript `5.2.2`、ESLint 8、Jest 29は今回据え置き、toolchain専用の後続Issueで一括更新します。

## Transitive Dependencies

| Package | Owner / 制約 | 確認事項 |
|---|---|---|
| `express@5.2.1` | `@nestjs/platform-express` のexact dependency | route、query、health、CORSをE2Eで確認する |
| `multer@2.1.1` | `@nestjs/platform-express` のexact dependency | file uploadは未使用。advisoryと上流更新を追跡する |
| `cors@2.8.6` | `@nestjs/platform-express` のexact dependency | direct dependencyにせず、preflightをE2Eで確認する |
| `lodash@4.18.1` | Nest Config / GraphQLの上流依存 | advisory解消版であることをauditで確認する |
| `graphql-ws@6.0.8` / `ws@8.20.1` | Nest GraphQLの上流依存 | subscriptions未使用。advisoryと上流更新を追跡する |
| `glob@10.5.0` | TypeORM `^10.5.0`から解決 | deprecated warningをTypeORM 1評価時に再確認する |

## Known Peer Warning Allowlist

root の `npm ls --all` で許容する非zero要因は、`@nestjs/apollo@13.4.2` が直接依存する `@apollo/server-plugin-landing-page-graphql-playground@4.0.1` の peer 宣言だけです。このpluginは `@apollo/server@^4` を宣言しますが、Nest Apollo 13はApollo Server 5を要求します。

アプリケーション設定ではdeprecatedなPlaygroundを使用せず、開発環境だけGraphiQLを有効化します。このwarningは上流の依存削除またはpeer範囲修正まで限定的に許容し、`@nestjs/apollo` 更新時に必ず再確認します。新しいpeer warningをこのallowlistへ暗黙に追加してはいけません。

## Audit Scope

- root: `npm audit` 0件を維持する
- client: rootとは分離して扱い、既知findingはIssue #365で追跡する
- repository全体について「脆弱性0件」と表現せず、root / client のscopeを明記する

## Follow-up Issue Plans

### Backend toolchain更新

- 目的: EOLのESLint 8、TypeScript、typescript-eslint、Jest / ts-jestを互換性のある系列へ一括更新する
- 対象: lint / test / build toolchainと関連設定
- 受け入れ条件: rootのlint、build、unit/E2E test、CIが成功し、runtime dependencyを変更しない
- 推奨ラベル: `type:chore`, `area:backend`, `area:ci-cd`, `risk:medium`, `cost:none`

### TypeORM 1.0移行評価

- 目的: TypeORM 0.3から1.0へのbreaking change、migration、PostgreSQL接続、repository APIへの影響を分離して評価する
- 対象: entity、repository、database config、migration / integration test
- 受け入れ条件: migration planとrollback、実DB integration test、deploy影響が明確になっている
- 推奨ラベル: `type:chore`, `area:backend`, `risk:medium`, `cost:none`

## 関連

- [Issue #369](https://github.com/kmryst/terraform-hannibal/issues/369)
- [Issue #365](https://github.com/kmryst/terraform-hannibal/issues/365)
- [ADR 0018](../adr/0018-adopt-node24-and-supported-dependency-lines.md)
