# 0036. 本番イメージの依存インストールで optional dependencies も除外する（`npm ci --omit=dev --omit=optional`）

## ステータス

Accepted

## 日付

2026-10-06

## 決定内容

`Dockerfile` の本番ステージの依存インストールを `npm ci --omit=dev` から `npm ci --omit=dev --omit=optional` に変更する。
あわせて `ts-morph` を `package.json` の `dependencies` から `devDependencies` へ移す（Issue #668）。

## 背景

`ts-morph` は、開発時（`NODE_ENV` が `production` 以外）だけ有効にする GraphQL の型定義生成（`definitions.path`）で `@nestjs/graphql` が遅延読み込みする package である。本番では読み込まれない。Issue #668 では、`devDependencies` へ移せば `npm ci --omit=dev` の本番イメージから外れると想定していた。

実際に `npm install --save-dev ts-morph@^28.0.0` で移すと、`package-lock.json` では `ts-morph` とその依存（`@ts-morph/common`、`minimatch`、`brace-expansion`、`balanced-match`、`code-block-writer`、`path-browserify`）に `"dev": true` ではなく `"devOptional": true` が付いた。
`ts-morph` は devDependency であると同時に、本番依存 `@nestjs/graphql@14.0.3` の optional な peer dependency（`peerDependenciesMeta` で `optional: true`）でもあるためである。npm は、dev 側と本番依存の optional 側の両方から到達する package を `devOptional` とし、`--omit=dev` と `--omit=optional` の両方を指定したときだけ除外する（[package-lock.json の `devOptional`](https://docs.npmjs.com/cli/v11/configuring-npm/package-lock-json)）。
そのため `--omit=dev` だけでは、移した後も本番イメージに `node_modules/ts-morph` と `node_modules/@ts-morph` が残った（npm 11.19.0、`node:24-alpine` で確認）。

変更前（main）の時点でも、`ts-node`、`typescript`、`@types/node` など 20 個の package が同じ理由（`typeorm` の optional peer `ts-node`、`@nestjs/graphql` の optional peer `typescript`）で `devOptional` になっており、本番イメージに入っていた。

## 検討した選択肢

### A. `npm ci --omit=dev --omit=optional` にする（採択）

- 長所: npm の標準オプションだけで、lockfile の `dev` / `devOptional` / `optional` の区別どおりに開発専用の package を除外できる。`ts-morph` 系 7 個に加えて、もともと入っていた `ts-node`、`typescript` などの開発用 package も外れる。本番イメージは 470MB → 399MB、本番の `node_modules` は 156MB → 112MB になった（ローカルの Docker build で計測）
- 短所: 本番依存の `optionalDependencies` も除外される。現時点で該当するのは `pg` の `pg-cloudflare` だけで、`pg` は Cloudflare Workers 上で動くときだけ読み込む（`pg/lib/stream.js` の `isCloudflareRuntime()`）。Node.js（ECS Fargate）では使わない。将来、実行時に必要な optional dependency（プラットフォーム別の native binary など）を持つ本番依存を追加すると、本番イメージから黙って落ちる

### B. `ts-morph` を `devDependencies` へ移すだけにする（`--omit=dev` のまま）

- 長所: Dockerfile を変えない
- 短所: 本番イメージから `ts-morph` が外れず、Issue #668 の目的（本番イメージを小さくする）を満たさない。`package.json` の宣言と本番イメージの中身が食い違い、読み手を誤解させる

### C. `npm ci --omit=dev` の後に `rm -rf node_modules/ts-morph node_modules/@ts-morph ...` で個別に削除する

- 長所: 本番依存の optional dependencies には影響しない
- 短所: 削除する package を名前で列挙するため、`ts-morph` の依存が変わると追従が必要になる。`node_modules` を lockfile と食い違った状態にする

### D. `ts-morph` を `package.json` から削除する

- 長所: 本番イメージから確実に外れる
- 短所: 開発モードの起動と e2e（`test/runtime.e2e-spec.ts`）が `Cannot find module 'ts-morph'` で失敗する（Issue #668 で確認済み）。開発時の型定義生成（`src/graphql/graphql.schema.ts`）を使い続けるため採れない

## 採択理由

- `package.json` の宣言（開発専用）と本番イメージの中身を一致させられるのは A と C で、A は npm の標準オプションで lockfile の区別に従うため、package 名の列挙を保守しなくてよい
- A の短所（本番依存の optional dependencies が落ちる）は、現時点で該当するのが `pg-cloudflare` だけで、本番の実行環境では使わない
- 本番イメージの起動 smoke test（`pr-check` の `Docker Build` job の `Smoke test production startup`：PostgreSQL に接続し、起動時の migrations 適用後に `/health` と GraphQL の `routes` を確認する）で、本番依存だけの状態で起動できることを検証している

## 影響

- 本番イメージから `ts-morph` 系 7 個と、`ts-node`・`typescript` などの開発用 package が外れる
- `npm audit --omit=dev` は `devOptional` の package を引き続き対象にする（`--omit=optional` を付けた audit とは対象が異なる）。Dependency Audit の呼び出し方は idp-golden-path 側の reusable workflow が決めるため、この ADR では変えない
- 本番依存を追加・更新するときは、その package が実行時に `optionalDependencies` を必要としないかを確認する。必要な場合は、その package を root の `dependencies` に直接宣言すれば `optional` ではなくなり、本番イメージに入る

### 再検討条件

- 実行時に必要な optional dependency を持つ本番依存を追加するとき
- npm の `--omit` / `devOptional` の扱いが変わったとき
- 本番の実行環境を Node.js（ECS Fargate）以外（Cloudflare Workers など）へ移すとき

## 関連

- Issue [#668](https://github.com/kmryst/terraform-hannibal/issues/668)
- [ADR 0034](./0034-keep-backend-commonjs-and-load-esm-nestjs-via-require-esm.md)（NestJS 12 系への移行）
- [依存関係管理](../operations/dependency-management.md)
- [npm Docs: package-lock.json](https://docs.npmjs.com/cli/v11/configuring-npm/package-lock-json)
- [npm Docs: npm ci（`--omit`）](https://docs.npmjs.com/cli/v11/commands/npm-ci)
