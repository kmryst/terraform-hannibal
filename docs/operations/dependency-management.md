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
| NestJS core / common / platform / testing | `11.1.28` | NestJS 11系列を同一patchへ統一する | NestJS 12 stable と周辺moduleの対応後 |
| NestJS GraphQL / Apollo | `13.4.2` | NestJS 11、GraphQL 16、Apollo Server 5の統合 | 14系stable、またはPlayground依存除去時 |
| Apollo Server | `5.5.1` | Apollo Server 4 EOL後のsupported line | 6系stableとNestJS対応後 |
| Express integration | `@as-integrations/express5@1.1.2` | Nest Apollo 13がruntimeで直接loadする | Nest Apolloのdependency宣言変更時 |
| GraphQL.js | `16.14.2` | Apollo/Nestのsupported stable major（Dependabotのmajor更新はignoreで抑止、Issue #564で追跡） | GraphQL 17 stableと全peer対応後 |
| TypeORM | `1.1.0` | TypeORM 1系のsupported line。1.0で削除されたAPI（string形式のselect/relations、`Connection`、global functions等）は本リポジトリで未使用 | TypeORM 2系 stable と `@nestjs/typeorm` 対応後 |
| reflect-metadata | `0.2.2` | NestJS / TypeORMのデコレータ・メタデータ基盤。0.xのためsemver上はminorでも実質major扱いで検証する。`typeorm@1.1.0` が `^0.2.2` を直接依存に持つ | NestJS / TypeORM側の要求range変更時 |
| Node.js types | `24.13.3` | runtime majorと型定義majorを一致させる（Dependabotのmajor更新はignoreで抑止、Issue #555で追跡） | Node runtime major更新時 |

`@nestjs/config@4.0.4`、`@nestjs/typeorm@11.0.3`、`@nestjs/schematics@11.1.0`、`ts-morph@28.0.0` も上記contractに合わせます。toolchainは TypeScript `5.9.3`（5系最新）、Jest 30、`@nestjs/cli@11.0.24` へ更新済みです。ESLint 8 のみ flat config 移行（Issue #551）完了まで据え置き、Dependabot の major 更新を ignore で抑止しています。

TypeORM 1.1.0 への更新（PR #547）は、Docker 上の PostgreSQL 16 に対するスモークテスト（アプリ起動、`synchronize` によるスキーマ自動生成、GraphQL 経由の createRoute / routes / seedRoutes の成功）と unit test を検証済みです。AWS dev 環境での実地 CRUD 確認は未了であり、次回 `deploy.yml`（workflow_dispatch）実行時に行います。

## 現行 Frontend Contract

`client/` は root とは独立した npm プロジェクトです。前節の Backend Contract は root（NestJS backend）のみを対象とし、client の依存は以下を正本とします。

| 領域 | 採用 version | 用途・制約 | 再検討条件 |
|---|---:|---|---|
| Apollo Client | `4.2.10` | React frontend の GraphQL client。4 系で React 向け export が `@apollo/client` から `@apollo/client/react` へ移動し、`ApolloClient` の `uri` ショートハンドが廃止されて `link` が必須になった | 5 系 stable と React 対応後 |
| GraphQL.js | `17.0.2` | `@apollo/client@4` の peer が `^16.0.0 \|\| ^17.0.0` で 17 を許容する。root（backend）は Apollo Server / Nest GraphQL の peer 制約により 16 系のまま据え置く | root 側が 17 へ揃った時点で両者の major 一致を再検討 |
| rxjs | `7.8.2` | `@apollo/client@4` の**必須** peer（`^7.3.0`、`peerDependenciesMeta` で optional 指定されていない）。3 系が dependencies に持っていた `zen-observable-ts` の置き換え先。アプリケーションコードから直接 import はしないが、宣言を省くと peer 未充足になる | Apollo Client が Observable 実装を変更した場合 |
| React / React DOM | `19` 系 | `@apollo/client@4` の peer は `>=19.0.0-rc` を許容する | React 20 stable と Apollo Client 対応後 |

`@apollo/client@4.2.10` の peer のうち `react` / `react-dom` / `graphql-ws` / `subscriptions-transport-ws` は `peerDependenciesMeta` で optional です。client は GraphQL subscription を使わないため、`graphql-ws` / `subscriptions-transport-ws` は導入しません。

### root（GraphQL 16）と client（GraphQL 17）の major 分岐

root と client は独立した npm プロジェクトであり、両者の通信は GraphQL over HTTP です。GraphQL.js のバージョンは各プロセス内のスキーマ構築・クエリ実行の実装詳細であり、ワイヤ上でやり取りされるのは HTTP + JSON のリクエスト / レスポンスのため、major が分かれても通信要件には影響しません。

この点は推論だけで済ませず、Issue #566 の移行時にローカル実測しています。Docker 上の PostgreSQL 16 で backend（graphql 16.14.2）を起動し、client（graphql 17.0.2 / Apollo Client 4.2.10）を dev server と production build の双方から実ブラウザで開き、`GetMapData` クエリが 200 で成功して地図レイヤーが描画されること、コンソールに Apollo / GraphQL 由来のエラーが出ないことを確認しました。

root 側の graphql major 更新の扱いは Issue #564 / PR #565 で別途整理します。

## Transitive Dependencies

| Package | Owner / 制約 | 確認事項 |
|---|---|---|
| `express@5.2.1` | `@nestjs/platform-express` のexact dependency | route、query、health、CORSをE2Eで確認する |
| `multer@2.2.0` | `@nestjs/platform-express` のexact dependency | file uploadは未使用。advisoryと上流更新を追跡する（Issue #514でDoS脆弱性2件を解消） |
| `cors@2.8.6` | `@nestjs/platform-express` のexact dependency | direct dependencyにせず、preflightをE2Eで確認する |
| `lodash@4.18.1` | Nest Config / GraphQLの上流依存 | advisory解消版であることをauditで確認する |
| `graphql-ws@6.0.8` / `ws@8.21.0`（`package.json` の `overrides` で固定） | Nest GraphQLの上流依存 | subscriptions未使用。`@nestjs/graphql@13.4.2` は `ws@8.20.1`（脆弱、GHSA-96hv-2xvq-fx4p）を厳密ピン留めしており、13.4.2が現時点で最新の安定版のため上流修正待ちができない。`overrides` で `@nestjs/graphql` 配下の `ws` のみ `8.21.0`（パッチ済み）に固定する（Issue #515）。`@nestjs/graphql` のバージョン自体は変更しない |
| `subscriptions-transport-ws@0.11.0` / `ws@7.5.11` | `@nestjs/graphql` の推移的依存 | `ws@^7` のみ対応（8.x非対応）のため、上記 `ws` overrideの対象から明示的に除外し `7.5.11`（既にパッチ済み）に固定する。ネストした `overrides` の書き方は `package.json` を参照 |
| `glob@10.5.0` | Jest 30系（`@jest/reporters` / `jest-config` / `jest-runtime` が `^10.5.0` を要求）から解決。TypeORM 1.1.0 は glob 非依存になった（`tinyglobby` へ移行） | devDependency経路のみ。Jest更新時に再確認する |

## Known Peer Warning Allowlist

root の `npm ls --all` で許容する非zero要因は、`@nestjs/apollo@13.4.2` が直接依存する `@apollo/server-plugin-landing-page-graphql-playground@4.0.1` の peer 宣言だけです。このpluginは `@apollo/server@^4` を宣言しますが、Nest Apollo 13はApollo Server 5を要求します。

アプリケーション設定ではdeprecatedなPlaygroundを使用せず、開発環境だけGraphiQLを有効化します。このwarningは上流の依存削除またはpeer範囲修正まで限定的に許容し、`@nestjs/apollo` 更新時に必ず再確認します。新しいpeer warningをこのallowlistへ暗黙に追加してはいけません。

## Audit Scope

- root: `npm audit` 0件を維持する
- client: rootとは分離して扱い、既知findingはIssue #365で追跡する
- repository全体について「脆弱性0件」と表現せず、root / client のscopeを明記する

## 有効な Dependabot ignore

`.github/dependabot.yml` で major 更新を抑止している依存の一覧です。ignore は恒久措置ではなく、必ず解除条件と見直し期限、追跡 Issue を持たせます。

各行が「なぜこの ignore があるか」の正本は `.github/dependabot.yml` のコメントです。この表は「今いくつ・何を止めているか」を1箇所で把握するための索引として維持します。新しい ignore を追加・解除したときは、この表も同じ PR で更新します。

| 対象 | 種別 | 対象エントリ | 理由 | 解除条件 | 見直し期限 | 追跡 |
|---|---|---|---|---|---|---|
| `typescript` | major | root `/` と `/client` | `@typescript-eslint/eslint-plugin@8.66.0` の peer が `typescript ">=4.8.4 <6.1.0"`。root は `npm ci` が ERESOLVE で失敗（PR #537）、client は TS5108 `esModuleInterop` 廃止でビルド失敗（PR #532）。devDependency のため本番影響なし | `@typescript-eslint/eslint-plugin` の peer から `<6.1.0` の上限が外れたら（上流待ち） | 2026-11-02 | [Issue #542](https://github.com/kmryst/terraform-hannibal/issues/542) |
| `eslint` | major | root `/` のみ | ESLint v9 で flat config が既定、v10 で eslintrc 形式のサポートが削除された。本リポジトリは `.eslintrc.js` のままで未移行のため、`ESLint couldn't find an eslint.config.(js\|mjs\|cjs) file.` で lint が失敗（PR #546）。devDependency のため本番影響なし。client には ESLint 関連の依存も lint script もないため `/client` には追加しない | flat config（`eslint.config.js`）への移行完了（上流待ちではなく本リポジトリ自身の作業） | 2026-11-02 | [Issue #551](https://github.com/kmryst/terraform-hannibal/issues/551) |
| `@types/node` | major | root `/` のみ | runtime major と型定義 major を一致させる contract（前節「現行 Backend Contract」）。runtime は Node 24（`node:24-alpine` / `engines >=24 <25`）のため、26 系型定義は「runtime に存在しない API が型チェックを通る」リスクがある（PR #554 で 26.1.2 が提案された）。devDependency のため本番影響なし | Node runtime の major 更新（`node:24-alpine` / `setup-node` / `engines`）と同時に外す | 2026-11-02 | [Issue #555](https://github.com/kmryst/terraform-hannibal/issues/555) |
| `graphql` | major | root `/` のみ | `@apollo/server@5.5.1` と `@nestjs/graphql@13.4.2`（いずれも 2026-08-06 時点で npm latest）の peer がどちらも `graphql "^16.11.0"` で、graphql 17 を受け付けない。root は `npm ci` が ERESOLVE で失敗（PR #541）。production dependency のため `--force` / `--legacy-peer-deps` による強制解決はしない。client 側（PR #533）は `@apollo/client` を 4 系へ上げれば通せる（`3.13.4` の peer は `graphql "^15.0.0 \|\| ^16.0.0"`、`4.2.9` は `"^16.0.0 \|\| ^17.0.0"`）ため `/client` には追加しない | `@apollo/server` と `@nestjs/graphql`（または後継 major）の peer が `graphql ^17` を許容したら（上流待ち） | 2026-11-02 | [Issue #564](https://github.com/kmryst/terraform-hannibal/issues/564) |

## Follow-up Issue Plans

かつてここに挙げていた「Backend toolchain更新」（TypeScript / typescript-eslint / Jest / ts-jest）と「TypeORM 1.0移行評価」は対応済みです（TypeScript 5.9.3 / Jest 30 は PR #557、TypeORM 1.1.0 は PR #547）。

Dependabot の ignore 解除に関する追跡 Issue は前節「有効な Dependabot ignore」の表に集約しました。それ以外の残る追跡事項は次のとおりです。

- TypeORM 1.1.0 の AWS dev 環境での実地 CRUD 確認: 次回 `deploy.yml` 実行時（「現行 Backend Contract」節参照）

## 関連

- [Issue #369](https://github.com/kmryst/terraform-hannibal/issues/369)
- [Issue #365](https://github.com/kmryst/terraform-hannibal/issues/365)
- [ADR 0018](../adr/0018-adopt-node24-and-supported-dependency-lines.md)
