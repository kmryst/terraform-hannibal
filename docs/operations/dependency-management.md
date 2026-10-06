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
| NestJS core / common / platform / testing | core `11.1.28` / common・testing `11.2.1` / platform-express `11.2.7` | NestJS 11系列内に揃える。platform-express は multer の advisory 解消のため lockfile 更新で 11.2.7 に上げた（Issue #651） | NestJS 12 stable と周辺moduleの対応後 |
| NestJS GraphQL / Apollo | `13.4.5` | NestJS 11、GraphQL 16、Apollo Server 5の統合 | 14系stable、またはPlayground依存除去時 |
| Apollo Server | `5.5.1` | Apollo Server 4 EOL後のsupported line | 6系stableとNestJS対応後 |
| Express integration | `@as-integrations/express5@1.1.2` | Nest Apollo 13がruntimeで直接loadする | Nest Apolloのdependency宣言変更時 |
| GraphQL.js | `16.14.2` | Apollo/Nestのsupported stable major（Dependabotのmajor更新はignoreで抑止、Issue #564で追跡） | GraphQL 17 stableと全peer対応後 |
| TypeORM | `1.1.0` | TypeORM 1系のsupported line。1.0で削除されたAPI（string形式のselect/relations、`Connection`、global functions等）は本リポジトリで未使用 | TypeORM 2系 stable と `@nestjs/typeorm` 対応後 |
| reflect-metadata | `0.2.2` | NestJS / TypeORMのデコレータ・メタデータ基盤。0.xのためsemver上はminorでも実質major扱いで検証する。`typeorm@1.1.0` が `^0.2.2` を直接依存に持つ | NestJS / TypeORM側の要求range変更時 |
| Node.js types | `24.13.3` | runtime majorと型定義majorを一致させる（Dependabotのmajor更新はignoreで抑止、Issue #555で追跡） | Node runtime major更新時 |

`@nestjs/config@4.0.4`、`@nestjs/typeorm@11.0.3`、`@nestjs/schematics@11.1.0`、`ts-morph@28.0.0` も上記contractに合わせます。toolchainは TypeScript `6.0.3`、Jest 30、`@nestjs/cli@11.0.24` へ更新済みです。

TypeScript は `~6.0.3`（6.0 系の patch のみ許容）で宣言します（Issue #663）。NestJS 12 系の `@nestjs/schematics@12` は peer に `typescript >=6.0.0`、`@nestjs/cli@12` は `typescript ~6.0.2` を要求するため、NestJS 12 系移行の前提として 6 系へ上げました。一方で `typescript-eslint@8.71.1` の peer は `typescript >=4.8.4 <6.1.0` のため、6.1 以降には上げません。7 系（2026-10-06 時点の最新は 7.0.2）への major 更新は Dependabot の ignore で抑止しています（Issue #542）。`client/` は対象外で、TypeScript 5 系のままです。

TypeScript 6 で既定値が変わったため、次の設定を明示しています。

- `tsconfig.build.json` の `rootDir`（`./src`）: 明示しないと TS5011 で build が失敗する
- `tsconfig.build.json` の `tsBuildInfoFile`（`./dist/tsconfig.build.tsbuildinfo`）: `rootDir` を `./src` にすると、incremental build の `.tsbuildinfo` の既定の出力先が `dist/` の外（リポジトリ直下）に変わる。`nest build` は `deleteOutDir` で `dist/` だけを消すため、`.tsbuildinfo` が残ると TypeScript が変更なしと判断して何も出力せず、`dist/main.js` のないイメージができる（`.tsbuildinfo` が残ったローカルの作業ツリーから `docker build` すると、`COPY . .` でイメージに持ち込まれて再現した）。出力先を `dist/` 配下に固定して、`dist/` と一緒に消えるようにしている
- `tsconfig.json` の `types`（`node` / `jest`）: 既定値が空になり、Jest のグローバル（`describe` / `expect` など）の型が読み込まれなくなるため
- `esModuleInterop` が既定で有効になったため、CommonJS の `supertest` は `import request from 'supertest'`（default import）で読み込む

`@nestjs/cli@11.0.24` は `typescript@5.9.3` を exact で依存に持つため、lockfile には `node_modules/@nestjs/cli/node_modules/typescript@5.9.3` が入れ子で残ります。`nest build` の型チェックと出力は root の `typescript@6.0.3` を使います。この入れ子は NestJS 12 系（`@nestjs/cli@12`）への移行時に解消します。ESLint 8 のみ flat config 移行（Issue #551）完了まで据え置き、Dependabot の major 更新を ignore で抑止しています。

TypeORM 1.1.0 への更新（PR #547）は、Docker 上の PostgreSQL 16 に対するスモークテスト（アプリ起動、`synchronize` によるスキーマ自動生成、GraphQL 経由の createRoute / routes / seedRoutes の成功）と unit test を検証済みです。AWS dev 環境での実地 CRUD 確認は未了であり、次回 `deploy.yml`（workflow_dispatch）実行時に行います。

## 現行 Frontend Contract

`client/` は root とは独立した npm プロジェクトです。前節の Backend Contract は root（NestJS backend）のみを対象とし、client の依存は以下を正本とします。

| 領域 | 採用 version | 用途・制約 | 再検討条件 |
|---|---:|---|---|
| Apollo Client | `4.2.10` | React frontend の GraphQL client。4 系で React 向け export が `@apollo/client` から `@apollo/client/react` へ移動し、`ApolloClient` の `uri` ショートハンドが廃止されて `link` が必須になった | 5 系 stable と React 対応後 |
| GraphQL.js | `17.0.2` | `@apollo/client@4` の peer が `^16.0.0 \|\| ^17.0.0` で 17 を許容する。root（backend）は Apollo Server / Nest GraphQL の peer 制約により 16 系のまま据え置く | root 側が 17 へ揃った時点で両者の major 一致を再検討 |
| rxjs | `7.8.2` | `@apollo/client@4` の**必須** peer（`^7.3.0`、`peerDependenciesMeta` で optional 指定されていない）。3 系が dependencies に持っていた `zen-observable-ts` の置き換え先。アプリケーションコードから直接 import はしないが、宣言を省くと peer 未充足になる | Apollo Client が Observable 実装を変更した場合 |
| React / React DOM | `19` 系 | `@apollo/client@4` の peer は `>=19.0.0-rc` を許容する | React 20 stable と Apollo Client 対応後 |
| mapbox-gl | `3.27.0` | 地図描画ライブラリ。3 系は型定義（`dist/mapbox-gl.d.ts`）を同梱するため `@types/mapbox-gl` は不要（3.5.0 以降は deprecated stub になっており導入しない）。同梱 d.ts は ambient `GeoJSON` namespace を参照するが `@types/geojson` への依存を宣言していないため、client 側で direct devDependency として持つ | mapbox-gl 4 系 stable 後 |
| @types/geojson | `7946.0.16` | `geojson` モジュールと ambient `GeoJSON` namespace の供給元。アプリケーションコード（`mapLayers.ts` / `mapUtils.ts` / `MapContainer.tsx`）と mapbox-gl 同梱 d.ts の両方が必要とする。旧 `@types/mapbox-gl@3.4.1` が推移的に供給していたが、stub 化（PR #535 で 3.5.0 へ更新提案）で供給が途切れるため direct 化した | mapbox-gl が型依存を自己完結させた場合 |

`@apollo/client@4.2.10` の peer のうち `react` / `react-dom` / `graphql-ws` / `subscriptions-transport-ws` は `peerDependenciesMeta` で optional です。client は GraphQL subscription を使わないため、`graphql-ws` / `subscriptions-transport-ws` は導入しません。

### root（GraphQL 16）と client（GraphQL 17）の major 分岐

root と client は独立した npm プロジェクトであり、両者の通信は GraphQL over HTTP です。GraphQL.js のバージョンは各プロセス内のスキーマ構築・クエリ実行の実装詳細であり、ワイヤ上でやり取りされるのは HTTP + JSON のリクエスト / レスポンスのため、major が分かれても通信要件には影響しません。

この点は推論だけで済ませず、Issue #566 の移行時にローカル実測しています。Docker 上の PostgreSQL 16 で backend（graphql 16.14.2）を起動し、client（graphql 17.0.2 / Apollo Client 4.2.10）を dev server と production build の双方から実ブラウザで開き、`GetMapData` クエリが 200 で成功して地図レイヤーが描画されること、コンソールに Apollo / GraphQL 由来のエラーが出ないことを確認しました。

root 側の graphql major 更新は、PR #565 で Dependabot の ignore に追加して抑止済みです（root `/` のみが対象で `/client` は対象外）。解除条件と見直し期限の正本は `.github/dependabot.yml` のコメント（後述「有効な Dependabot ignore」参照）、追跡は Issue #564 を参照してください。

## Transitive Dependencies

| Package | Owner / 制約 | 確認事項 |
|---|---|---|
| `express@5.2.1` | `@nestjs/platform-express` のexact dependency | route、query、health、CORSをE2Eで確認する |
| `multer@2.4.0` | `@nestjs/platform-express` のexact dependency | file uploadは未使用。advisoryと上流更新を追跡する（Issue #514でDoS脆弱性2件、Issue #651で GHSA-535w-7cp7-47q4 ほかを解消） |
| `cors@2.8.6` | `@nestjs/platform-express` のexact dependency | direct dependencyにせず、preflightをE2Eで確認する |
| `lodash@4.18.1` | Nest Config / GraphQLの上流依存 | advisory解消版であることをauditで確認する |
| `graphql-ws@6.2.1` / `ws@8.21.3` | Nest GraphQLの上流依存（`@nestjs/graphql@13.4.5` が `ws@8.21.3` をexact dependencyで宣言。`graphql-ws` は `ws@^8` をoptional peerとして要求し、同じ `ws` を共有する） | subscriptionsは未使用（`subscriptions` 設定なし、スキーマに `Subscription` 型なし）だが、`@nestjs/graphql` の読み込み時に `ws` / `graphql-ws` / `subscriptions-transport-ws` のモジュール自体はruntimeでloadされる。`overrides` での固定はしない。経緯: `@nestjs/graphql@13.4.2` が `ws@8.20.1`（脆弱、GHSA-96hv-2xvq-fx4p）をexactで宣言していたため、Issue #515（PR #517）で `overrides` により `ws@8.21.0` に固定していた。`@nestjs/graphql@13.4.5` への更新で上流の宣言が修正版の `8.21.3` になり、override が逆に `8.21.3` から `8.21.0` へのダウングレードになったため、Issue #660 で外した。8.21.1 には GHSA-96hv-2xvq-fx4p の修正の補強（空のフラグメントも `maxFragments` の上限に数える、`maxBufferedChunks` / `maxFragments` の既定値の引き下げ）が含まれる。`@nestjs/graphql` 更新時は `npm ls ws --all` で解決結果を確認する |
| `subscriptions-transport-ws@0.11.0` / `ws@7.5.11` | `@nestjs/graphql@13.4.5` の推移的依存。`ws@^5.2.0 \|\| ^6.0.0 \|\| ^7.0.0` を要求する | `ws@^7` までしか対応しない（8.x非対応）。`ws@7.5.11` は7.x系の最新で GHSA-96hv-2xvq-fx4p の修正版のため、`overrides` での固定はしない（Issue #515 の入れ子の override は Issue #660 で外した）。7.x系に新しいadvisoryが出た場合はDependency Auditで検出して対処する。`@nestjs/graphql@14`（NestJS 12系）は `subscriptions-transport-ws` のサポートを削除しているため、移行時にこの経路はなくなる |
| `@graphql-tools/utils@12.0.3`（`package.json` の `overrides` で固定） | `@nestjs/graphql` / `@graphql-tools/merge` / `@graphql-tools/schema`（`@apollo/server` 経由）の上流依存。本番依存 | `@nestjs/graphql@13.4.5`（NestJS 11 系の最新）は `@graphql-tools/utils@12.0.0`（脆弱、GHSA-7mx3-vvmw-hjmv。`mergeDeep` の prototype pollution）を厳密ピン留めしており、修正版を要求する `@nestjs/graphql@14` は NestJS 12 系が前提のため上流修正待ちができない。本番依存の audit は期限付き例外の対象外のため、`overrides` で全経路の `@graphql-tools/utils` を `12.0.3`（修正版の最新）に固定する（Issue #658）。`@nestjs/graphql` のバージョン自体は変更しない。12.0.3 は `@whatwg-node/promise-helpers@^2.0.0`（Node `>=22.15.0`）を要求するため、同 package も 1.3.2 から 2.0.0 に上がる。解除条件: NestJS 12 系（`@nestjs/graphql@14`）へ移行したら override を外す |
| `glob@10.5.0` | Jest 30系（`@jest/reporters` / `jest-config` / `jest-runtime` が `^10.5.0` を要求）から解決。TypeORM 1.1.0 は glob 非依存になった（`tinyglobby` へ移行） | devDependency経路のみ。Jest更新時に再確認する |

## Known Peer Warning Allowlist

root の `npm ls --all` で許容する非zero要因は、`@nestjs/apollo@13.4.2` が直接依存する `@apollo/server-plugin-landing-page-graphql-playground@4.0.1` の peer 宣言だけです。このpluginは `@apollo/server@^4` を宣言しますが、Nest Apollo 13はApollo Server 5を要求します。

アプリケーション設定ではdeprecatedなPlaygroundを使用せず、開発環境だけGraphiQLを有効化します。このwarningは上流の依存削除またはpeer範囲修正まで限定的に許容し、`@nestjs/apollo` 更新時に必ず再確認します。新しいpeer warningをこのallowlistへ暗黙に追加してはいけません。

## Audit Scope

- root: `npm audit` 0件を維持する
  - 2026-10-06 時点の残件: `braces`（GHSA-vfj7-8cjw-p6xm、devDependency のみ）の high は、修正版が公開されていないため lockfile の更新では解消できない（Issue #651）。下の「期限付き例外」で扱う
  - 本番依存の `@graphql-tools/utils`（GHSA-7mx3-vvmw-hjmv）は、`overrides` で修正版 `12.0.3` に固定して解消した（Issue #658、上の「Transitive Dependencies」参照）。`npm audit --omit=dev` は 0 件を維持する
- client: rootとは分離して扱い、既知findingはIssue #365で追跡する
- repository全体について「脆弱性0件」と表現せず、root / client のscopeを明記する

### 期限付き例外（npm-audit-exceptions）

root の `root / Dependency Audit` は、idp-golden-path の reusable workflow（`dependency-audit.yml@v1`）に `npm-audit-exceptions` input を渡し、修正版のない high advisory を GHSA 単位で期限付きの例外にしている（[ADR 0033](../adr/0033-adopt-expiring-npm-audit-exception-for-braces.md)、契約の正本は idp-golden-path ADR 0008 の追記 2026-07-28）。宣言場所は `.github/workflows/dependency-audit.yml` の root job の `with:` である。

| GHSA | package | 期限（expires） | 追跡 Issue |
|---|---|---|---|
| GHSA-vfj7-8cjw-p6xm | `braces`（`markdownlint-cli2` 経由の devDependency のみ） | 2026-12-31 | [#655](https://github.com/kmryst/terraform-hannibal/issues/655) |

#### 「root は `npm audit` 0件を維持する」との関係

期限付き例外は、0件という基準を緩めるものではない。修正版がなく、0件にする手段がまだない advisory について、期限を区切ったうえで基準から外していることを記録する仕組みである。例外を使うのは、次の条件を全部満たす advisory に限る。

- 修正版がない、または修正に major 更新が必要で、すぐには取り込めない
- devDependency だけに含まれ、本番イメージ（`npm ci --omit=dev`）に入らない。本番依存（`--omit=dev`）の audit は例外を見ずに判定されるため、本番依存の advisory は例外にしても fail のまま残る
- critical ではない（critical は評価器が例外にさせない）
- 解除条件を書いた追跡 Issue がある

例外を入れても、full audit で例外以外の high が残っていれば fail する。例外は 0 件の基準からの一時的な逸脱として扱い、追跡 Issue で解消まで追う。

#### 期限を更新する手順

1. 追跡 Issue の解除条件が揃っていないことを確認する（修正版の有無を `npm view <package> version` で、依存経路を `npm ls <package>` で確認する）
2. 露出を評価し直す（本番イメージに入らないこと、外部入力が渡る経路がないこと）。評価結果は追跡 Issue にコメントで残す
3. `dependency-audit.yml` の `expires` を、更新する日から最大 90 日以内の日付にする PR を作る。PR からは追跡 Issue を `Refs` で参照し、追跡 Issue は close しない

評価なしで期限だけを延ばさない。`expires` は UTC の日付で、評価器は「今日（UTC）から 90 日を超える日付」も「今日より前の日付」も拒否する。

#### 例外を解除する手順

1. 修正版を取り込む（宣言 range の中なら `npm update <package>` または `npm audit fix --package-lock-only` で lockfile を更新する）か、依存経路がなくなったことを `npm ls <package>` で確認する
2. `dependency-audit.yml` から該当する要素を削除する。例外が 0 件になったら `npm-audit-exceptions` の行ごと削除する（input が未指定または `[]` なら、評価器を使わない従来の `npm audit --audit-level=high` に戻る）
3. PR で追跡 Issue を `Closes` する。上の表と ADR 0033 の状態も更新する

#### 撤去 PR を自動で作らない理由

idp-golden-path ADR 0016 は、不要になった回避策・例外を撤去する PR を自動で作る仕組みだが、判定するのは idp-golden-path 自身の実行だけで、reusable workflow の消費側は対象外である。消費側へ広げる idp-golden-path#310 も実装されていない。本リポジトリで同じ仕組みを別に作ると判定条件がずれるため作らない。代わりに次の 3 つで、不要になった例外に気づく。

- 追跡 Issue（解除条件を書いたまま OPEN にしておく）
- Job Summary の stale 警告（例外の GHSA が検出されなくなると、評価器は pass したうえで `not detected (remove the stale exception)` を出す）
- 期限切れによる fail closed（最長 90 日で必ず判断を求められる）

## 有効な Dependabot ignore

major 更新を抑止している ignore の「なぜ」（理由 / 実測 / 解除条件 / 見直し期限）の正本は、
各リポジトリの `.github/dependabot.yml` のコメントです。解除条件の追跡は 1 ignore = 1 Issue とし、
`dependabot-ignore` ラベルを付けます。

有効な ignore の横断一覧はラベル検索で取得します。
手書きの索引表は機械検証されない写しで陳腐化するため廃止しました（PR #579）。

[user:kmryst label:dependabot-ignore is:issue is:open](https://github.com/search?q=user%3Akmryst+label%3Adependabot-ignore+is%3Aissue+is%3Aopen&type=issues)

## Follow-up Issue Plans

かつてここに挙げていた「Backend toolchain更新」（TypeScript / typescript-eslint / Jest / ts-jest）と「TypeORM 1.0移行評価」は対応済みです（TypeScript 5.9.3 / Jest 30 は PR #557、TypeORM 1.1.0 は PR #547）。

Dependabot の ignore 解除に関する追跡 Issue は、前節「有効な Dependabot ignore」のとおり `dependabot-ignore` ラベルの検索で横断把握します。それ以外の残る追跡事項は次のとおりです。

- TypeORM 1.1.0 の AWS dev 環境での実地 CRUD 確認: 次回 `deploy.yml` 実行時（「現行 Backend Contract」節参照）

## 関連

- [Issue #369](https://github.com/kmryst/terraform-hannibal/issues/369)
- [Issue #365](https://github.com/kmryst/terraform-hannibal/issues/365)
- [ADR 0018](../adr/0018-adopt-node24-and-supported-dependency-lines.md)
