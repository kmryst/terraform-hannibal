# 0018. Node.js 24とsupported dependency lineを採用する

## ステータス

Accepted

## 日付

2026-06-15

## 決定内容

application runtime、CI、containerのsupport contractをNode.js 24 LTSへ統一する。rootと`client/`の`engines.node`は`>=24 <25`とし、実行versionはDockerの`node:24-alpine`とGitHub Actionsの`actions/setup-node`で担保する。

security / compatibility対応でdependencyを更新する場合は、選択したsupported lineの最新stableを採用する。prereleaseや、対応に無関係なmajor migrationは同じ変更へ含めない。lockfileは全面再生成せず、対象dependencyを段階的に更新して差分reviewする。

この方針をIssue #369では次のように適用する。

- NestJS 11.1.26、Nest GraphQL / Apollo 13.4.2、Apollo Server 5.5.1、GraphQL 16.14.2を採用する
- GraphQL 17 RCは採用せず、GraphQL 16のstable lineを維持する
- TypeORMは脆弱性修正版を含む0.3.30へ更新し、TypeORM 1.0 migrationは後続Issueへ分離する
- deprecatedなPlaygroundを使用せず、開発環境はGraphiQL、本番環境はlanding pageとintrospectionを無効にする
- Apollo ServerのCSRF preventionを有効化し、無効化を互換性回避策として使用しない

## 背景

Node.js 20は2026年4月30日にEOLとなり、application runtimeとして継続することはsecurity updateとsupportの観点で不適切になった。

既存backendはNestJS 10、Nest GraphQL / Apollo 12、Apollo Server 3の依存が混在していた。Dependabot PR #362、#363、#368を個別適用するとNestJS 10/11とApollo 4/5のpeer dependencyが不整合になり、`npm ci`が成立しない。Apollo Server 3はEOLであり、既知脆弱性を持つNestJS、TypeORM、Express、Multer、lodash、wsも依存treeに残っていた。

単一packageの最小更新ではsupport contractを整合できないため、Node、NestJS、Apollo、GraphQL、TypeORMを互換性のある系列として一括移行する必要がある。一方、lint/test toolchainやTypeORM 1.0まで同時に更新すると、security remediationと独立したbreaking changeが混ざり、原因切り分けとrollbackが難しくなる。

## 検討した選択肢

### Node.js 20を継続する

- 長所: runtime変更がなく、短期的な差分が小さい
- 短所: EOL runtimeを継続し、security updateとupstream supportを失う

### Node.js 26 Currentを採用する

- 長所: より新しいruntimeを利用できる
- 短所: LTS前のCurrent releaseであり、CI/containerの長期support contractとして安定性が低い

### Node.js 24 LTSを採用する（採択）

- 長所: Active LTSのsecurity updateを受けられ、NestJS 11 / Apollo Server 5の要件を満たす
- 長所: runtime、CI、container、型定義を同じmajorへ統一できる
- 短所: native moduleやtoolchainを含む全build/testの再検証が必要になる

### GraphQL 17 RCを採用する

- 長所: 次期majorを先行利用できる
- 短所: prereleaseであり、NestJS/Apollo ecosystem全体のstable supportが揃っていない

### TypeORM 1.0を同時移行する

- 長所: 最新majorへ一度に移行できる
- 短所: repository API、設定、migrationに独立したbreaking changeがあり、脆弱性対応のblast radiusを不必要に広げる

### lockfileを削除して全面再生成する

- 長所: 手順が単純で、全transitive dependencyを最新解決しやすい
- 短所: 対応と無関係なlock値まで変わり、review可能性とrollback時の原因追跡を損なう

### CSRF preventionを無効化する

- 長所: legacy clientやsimple requestとの互換性問題を回避しやすい
- 短所: browserからのCSRFリスクを再導入する。現frontendはJSON POSTで要件を満たすため無効化する理由がない

## 採択理由

Node.js 24はLTSとして運用安定性とsecurity supportを両立し、Node 20 EOLへの直接的な解決になる。`engines`はcontractの可視化、Dockerと`actions/setup-node`は実行versionのenforcement pointとして役割を分ける。

dependencyは単純な「全package最新版」ではなく、互換性が確認できるsupported line単位で更新する。これにより既知脆弱性とpeer dependency不整合を解消しつつ、GraphQL 17 RCやTypeORM 1.0のような独立したriskを分離できる。

段階的lockfile更新は全面再生成より手順が増えるが、direct dependencyの選択とtransitive dependencyの変化をreviewでき、問題時に戻す範囲を明確にできる。CSRF preventionはfrontendのJSON POSTと両立するため有効化し、unsafe GETをE2Eで拒否確認する。

## 影響

### メリット

- EOLのNode.js 20とApollo Server 3をruntime contractから除外できる
- NestJS / Apollo / GraphQLのpeer dependencyを整合できる
- rootの既知npm advisoryを0件にできる
- Express 5、Multer 2、GraphiQL、CSRF preventionを実動作で検証できる
- dependency更新とlockfile reviewの再利用可能な運用基準を持てる

### デメリット

- Node.js 24未導入のlocal environmentでは`engines` warningが発生する
- `@nestjs/apollo@13.4.2`が内包するdeprecated Playground pluginのApollo Server 4 peer warningは上流修正まで残る
- ESLint 8、TypeScript 5.2、Jest 29などのtoolchain更新は後続対応になる
- TypeORM 1.0へのmigrationを別途計画する必要がある

### ロールバック

Issue #369のPRをrevertし、root/clientのmanifestとlockfile、Docker base image、GitHub ActionsのNode version、GraphQL/CORS設定を移行前へ戻す。既にNode 24 imageをdeploy済みの場合は、revert後のNode 20 imageをbuildしてCodeDeployで再deployする。database schemaやTerraform stateは変更しないため、data migrationやstate rollbackは不要である。

## 関連

- [Issue #369](https://github.com/kmryst/terraform-hannibal/issues/369) - 本ADRを実装する統合Issue
- [Issue #365](https://github.com/kmryst/terraform-hannibal/issues/365) - client側dependency findingの追跡
- [Dependency Management](../operations/dependency-management.md) - 現行の依存更新運用
- 統合PR: 本ADRを含むPR（作成後に番号を追記する）
