# 0034. NestJS 12 系への移行で backend を CommonJS のまま維持し、ES Module の `@nestjs/*` を `require(esm)` で読み込む

## ステータス

Accepted

## 日付

2026-10-06

## 決定内容

root（NestJS backend）を NestJS 12 系（`@nestjs/graphql` / `@nestjs/apollo` は 14 系）へ移行するにあたり、アプリケーションのモジュール形式は CommonJS（`tsconfig.json` の `"module": "commonjs"`、`package.json` に `"type"` なし）のまま維持する。
ES Module として配布される 12 系の `@nestjs/*` は、Node.js の `require(esm)`（CommonJS の `require()` から同期的な ES Module を読み込む機能）で読み込む。backend 全体の ESM 移行は行わない。

- runtime（`node:24-alpine`）、CI（`actions/setup-node` の `"24"`）、ローカル（`.mise.toml` の Node.js 24）はいずれも Node.js 24 で、`require(esm)` はフラグなしで有効である。本番イメージの起動ログに `ExperimentalWarning` が出ないことを実測した
- `@nestjs/typeorm` は 12.0.1 以上を使う。12.0.0 は `exports` が `import` 条件だけで、`require()` から解決できない
- Jest（30 系、`ts-jest` で CommonJS に変換）は、Jest 自身のモジュールローダーが `require()` を実装しているため、Node.js 本体の `require(esm)` を使えない。Jest が ES Module を読み込むには Node.js の `vm.SourceTextModule` が必要なため、`test` / `test:watch` / `test:cov` / `test:e2e` の npm script に `cross-env NODE_OPTIONS=--experimental-vm-modules` を、`test:debug` に `--experimental-vm-modules` を付ける

## 背景

NestJS 12（2026 年リリース）では、`@nestjs/core` / `@nestjs/common` / `@nestjs/graphql` / `@nestjs/typeorm` などの core package がすべて `"type": "module"` の ES Module として配布されるようになった。
[移行ガイド](https://docs.nestjs.com/migration-guide) と [v12.0.0 のリリースノート](https://github.com/nestjs/nest/releases/tag/v12.0.0) は、`require(esm)` により既存の CommonJS アプリケーションはそのまま動き、アプリケーション側の ESM 移行は任意だとしている。`nest upgrade` も ESM 移行は行わない。

一方で、テストランナーは影響を受ける。移行ガイドは、Jest 30 未満では ES Module のみの package を読み込めず、Jest 30 でも Node.js 24.9 未満では `ERR_REQUIRE_ASYNC_MODULE` / `Must use import to load ES Module` で失敗するとしている。
このリポジトリ（Node.js 24.18、Jest 30.4.2）でもフラグなしの `jest` は、`node_modules/@nestjs/apollo/dist/index.js` の `export` 文で `SyntaxError: Unexpected token 'export'` になり、全 suite が失敗した。`--experimental-vm-modules` を付けると unit 15 件・e2e すべてが通った。

移行の前提条件と経緯は Issue [#662](https://github.com/kmryst/terraform-hannibal/issues/662) を参照する。

## 検討した選択肢

### A. CommonJS のまま、`require(esm)` で ES Module の `@nestjs/*` を読み込む（採択）

- 変更範囲: `package.json` / `package-lock.json` の依存更新と Jest の npm script だけ。アプリケーションコード（`src/`）の変更は不要
- 長所: 依存更新と同じ PR でロールバック単位が小さく保てる。import 文・`__dirname`・Jest / ts-jest 設定に手を入れない。build（`nest build`）・unit・e2e・PostgreSQL での実行・本番 Docker コンテナの起動まで、変更前と同じ結果になることを確認した
- 短所: Jest の実行が Node.js の実験的機能である `--experimental-vm-modules`（`vm.Module` API、Stability: 1 - Experimental）に依存する（後述「影響」）。アプリケーションは CommonJS、依存は ES Module という混在が残り、将来 top-level `await` を使う ES Module（`require(esm)` で読めない）を依存に持つ package が出ると読み込めない

### B. backend 全体を ESM へ移行する

- 変更範囲: `package.json` に `"type": "module"`、`tsconfig.json` を `"module": "nodenext"` などへ変更、全 import 文への拡張子付与、`__dirname` / `process.cwd()` 依存箇所（`src/app.module.ts` の `join(process.cwd(), ...)` など）の見直し、Jest / ts-jest の ESM 設定（または Vitest への移行）
- 長所: NestJS 12 の新規プロジェクトの既定に揃い、`require(esm)` の制約（top-level `await` を含む ES Module は読めない）から外れる。Jest の `--experimental-vm-modules` 依存も、Vitest に移れば解消できる
- 短所: 変更範囲が依存更新とは独立に大きく、同じ PR に混ぜると問題が起きたときに原因の切り分けとロールバックが難しくなる。移行ガイド上も任意であり、今回の移行の必須条件ではない

### C. `@nestjs/typeorm` だけ 11 系に据え置く

- 採れない。`@nestjs/typeorm@11.0.3` の peer は `@nestjs/core` / `@nestjs/common` が `^10.0.0 || ^11.0.0` で、`@nestjs/core@12` と両立しない。`@nestjs/core` / `@nestjs/apollo` / `@nestjs/graphql` も相互に peer で縛られているため、`@nestjs/*` は一括で 12 系（GraphQL / Apollo は 14 系）に上げるしかない
- 12.0.0 の `exports` 問題（`require()` で解決できない）は、`default` 条件が追加された 12.0.1 以上を使うことで解消する

## 採択理由

- NestJS 公式が、CommonJS アプリケーションは `require(esm)` でそのまま動くとしており、ESM 移行を任意としている
- runtime / CI / ローカルのすべてが Node.js 24 で、`require(esm)` がフラグなし・警告なしで使える
- 今回の目的は NestJS 11 系の保守終了リスクの回避と、`@graphql-tools/utils` の `overrides`（GHSA-7mx3-vvmw-hjmv）の解除である。ESM 移行はこの目的に不要で、変更範囲とロールバック単位を小さく保つほうが安全である
- テストランナーの対応（Jest のフラグ）は npm script の変更だけで済み、CI の workflow は npm script 経由で Jest を呼ぶため workflow を変更しない

## 影響

- アプリケーションコード（`src/`）、Dockerfile、CI の workflow は変更しない
- Jest は `--experimental-vm-modules` 付きで実行する。テスト実行時に `ExperimentalWarning: VM Modules is an experimental feature` が 1 回出るが、無害なため抑止しない（フラグに依存していることが実行のたびに見えるようにする）
- npm script を経由せずに `npx jest` を直接実行すると、ES Module を読めずに失敗する。CI（`pr-check.yml` の `npm test -- --runInBand`）は npm script 経由である
- Jest の require(ESM) は Node.js 24.9 以上が必要（同期的な `vm` module API を使うため）。CI の `NODE_VERSION: "24"` は最新の 24.x に解決されるため満たす
- リスク:
  - `--experimental-vm-modules` は Node.js の実験的フラグで、Node.js の更新でフラグ名や挙動が変わる可能性がある。変わった場合はテストが実行できなくなる（本番 runtime はこのフラグを使わないため、影響はテストに限られる）
  - Jest の ESM 対応自体も experimental として扱われており、Jest の minor / major 更新で挙動が変わる可能性がある
  - いずれも失敗はテストの実行時に必ず表面化し（全 suite が失敗する）、本番に気づかないまま入ることはない

## 再検討条件

- `require(esm)` で読み込めない依存（top-level `await` を含む ES Module など）が backend の依存に入ったとき
- Node.js の次の major 更新（Node.js 26 への移行など）で、`require(esm)` または `--experimental-vm-modules` の扱いが変わったとき
- Jest の ESM 対応が安定版になった、またはフラグが不要になったとき（フラグを外す）
- Jest から Vitest への移行を検討するとき（ESM 移行と合わせて評価する）
- NestJS が CommonJS アプリケーションのサポートを縮小する方針を出したとき

## 関連

- Issue: [#662](https://github.com/kmryst/terraform-hannibal/issues/662)（NestJS 12 系への移行）、[#663](https://github.com/kmryst/terraform-hannibal/issues/663)（前提の TypeScript 6.0.3 更新）、[#658](https://github.com/kmryst/terraform-hannibal/issues/658)（`@graphql-tools/utils` の override）
- [ADR 0018](./0018-adopt-node24-and-supported-dependency-lines.md)（Node.js 24 と supported dependency line の採用）
- [Dependency Management](../operations/dependency-management.md)（現行 Backend Contract の正本）
- [NestJS Migration guide](https://docs.nestjs.com/migration-guide)、[NestJS v12.0.0 release notes](https://github.com/nestjs/nest/releases/tag/v12.0.0)
- [Node.js: Loading ECMAScript modules using require()](https://nodejs.org/api/modules.html#loading-ecmascript-modules-using-require)
