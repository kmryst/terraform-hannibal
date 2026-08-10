---
name: run-local-map
description: terraform-hannibal のバックエンド（NestJS + GraphQL）とフロントエンド（React + Vite + mapbox-gl）をローカルで起動し、ブラウザでハンニバル進軍ルートの地図描画を目視確認する手順。「ローカルで起動して」「ローカルで動かして」「地図を確認して」「地図の描画をチェックして」「mapbox の描画チェック」「mapbox-gl の更新を検証して」のような依頼で使う。
---

# ローカルで地図描画を確認する

バックエンドとフロントエンドをローカルで起動し、`http://localhost:5173/` で地図描画を目視確認するための手順。
2026-08-10 に WSL 上で実機検証済み。コマンドはそのまま実行できる。
未検証の箇所は本文中でその都度「未検証」と明記している（前提の Node.js バージョン、後片付けの前景 `Ctrl+C` 経路）。

作業ディレクトリはリポジトリルート（`terraform-hannibal/`）を前提とする。

## 前提

- Docker が利用できること
- Node.js 24 系が使えること

Node.js のバージョンについて: 2026-08-10 の検証はシステムの Node **v24.14.1** で実施した。
`.mise.toml` が宣言する **24.18.0**（`mise install` で入る version）での動作は未検証。
どちらも Node 24 系であり `engines.node` の `>=24 <25` を満たすため通る見込みだが、実測はしていない。

## 手順

### 1. Postgres を起動する

```bash
docker run -d --name hannibal-pg-local \
  -e POSTGRES_PASSWORD=devpass \
  -e POSTGRES_USER=devuser \
  -e POSTGRES_DB=hannibal \
  -p 55432:5432 \
  postgres:16-alpine
```

ホスト側ポートを `55432` にしているのは、ローカルに既存の Postgres（`5432`）がある場合に衝突させないため。

ready 待ちは次で確認する（実測 1 秒程度）。

```bash
docker exec hannibal-pg-local pg_isready -U devuser -d hannibal
```

### 2. バックエンドを起動する

リポジトリルートで実行する。まず依存をインストールする。

```bash
npm ci
```

`client/` 側と同様、ルート側も `node_modules` が lock file と乖離していることがあるため省略しない（後述の落とし穴を参照）。
2026-08-11 に実測して約 17 秒 / 928 packages で完了することを確認済み。

続いて起動する。

```bash
DATABASE_URL="postgresql://devuser:devpass@localhost:55432/hannibal?sslmode=disable" \
  NODE_ENV=development \
  PORT=3000 \
  npx nest start
```

起動確認（実測 1 秒程度で応答する）。

```bash
curl -s http://localhost:3000/health
```

`{"status":"ok",...}` が返れば起動完了。

### 3. クライアントの接続先を設定する

`client/.env.local` を作成する。

```bash
echo 'VITE_GRAPHQL_ENDPOINT=http://localhost:3000/graphql' > client/.env.local
```

### 4. フロントエンドを起動する

```bash
cd client && npm ci && npm run dev
```

`http://localhost:5173/` で開く。

### 5. 目視確認ポイント

- 赤いルート線が Carthago Nova からアルプス越えを経てカンナエまで**連続して**描画されていること
- ラベルが各マーカーの上下左右に散って配置されていること（`text-variable-anchor` が効いていることの確認。全ラベルが同じ向きに固まっていたら異常）
- Roma（鷲）/ Carthage（象）のカスタムアイコンが表示されていること
- ブラウザコンソールに `Map layers added successfully.` が出ていること

### 6. 後片付け

**起動した順の逆順で、一括で実施する。**

1. vite dev サーバを停止する
2. NestJS バックエンドを停止する
3. Postgres コンテナを削除する
4. `client/.env.local` を削除する
5. 自動生成された `src/graphql/graphql.schema.ts` を revert する

#### 1-2. vite dev サーバと NestJS バックエンドを停止する

このスキルの主な利用者は AI エージェントであり、プロセスはバックグラウンド（非対話）で起動されるため、`Ctrl+C` を送れない前提で手順を組む。
listener を握っている PID を `ss -ltnp` から特定して停止する。2026-08-10 に実測で動作確認済み。

```bash
# listener を握っている PID を特定して停止する（vite → backend の順）
for port in 5173 3000; do
  pids=$(ss -ltnp 2>/dev/null | grep ":$port " | grep -oP 'pid=\K[0-9]+' | sort -u)
  for pid in $pids; do kill $pid 2>/dev/null; done
done
sleep 3
# 残っていれば SIGKILL
for port in 5173 3000; do
  pids=$(ss -ltnp 2>/dev/null | grep ":$port " | grep -oP 'pid=\K[0-9]+' | sort -u)
  for pid in $pids; do kill -9 $pid 2>/dev/null; done
done
ss -ltn 2>/dev/null | grep -E ":3000|:5173" || echo "listener なし"
```

- ポートの並び順 `5173 3000` が vite → バックエンドの停止順序を担保している。依存する側から先に落とすこと
- `npx nest start` はラッパー経由で起動するため、`npm exec` / `nest start` のプロセスを kill しても**実際にポートを握っている子プロセスが生き残る**（実測）。プロセス名ではなく `ss -ltnp` からポートを握っている実プロセスの PID を拾う方式が確実
- 最後の `ss -ltn` で listener が消えたことを必ず確認する。`listener なし` と出れば停止完了。プロセス一覧が空になっただけでは不十分

前景で起動した端末が手元にある場合は、その端末で `Ctrl+C` を押しても止められる（1 → 2 の順）。ただしこの経路は未検証であり、いずれにせよ上の `ss -ltn` による listener 確認は行う。

#### 3-5. 依存される側を片付ける

listener が消えたことを確認してから実行する。

```bash
docker rm -f hannibal-pg-local
rm -f client/.env.local
git checkout -- src/graphql/graphql.schema.ts
```

順序を守る理由: 依存される側（Postgres コンテナ・`client/.env.local`）を先に消し、依存する側（バックエンド・vite dev サーバ）を起動したまま放置すると、
バックエンドが DB を失った状態で `/health` だけ 200 を返す紛らわしい状態になる（実測）。

## 落とし穴

### `npm run start:dev` は Linux / WSL では使えない

`package.json` の `start:dev` は `set NODE_ENV=development&& nest start --watch` という **Windows cmd 構文**のため、Linux / WSL では失敗する。
手順 2 の形で環境変数を直接渡すこと。

### バックエンドは DB がないと起動しない

`AppModule` の `TypeOrmModule.forRoot` により、起動時に Postgres への接続を要求する。
地図が使う 3 クエリ（`capitalCities` / `hannibalRoute` / `pointRoute`）自体は `src/geojson_data/` の静的データを返すため DB 非依存だが、DB がないとアプリ自体が起動しない。
「地図を見るだけだから DB は不要」と判断して手順 1 を飛ばさないこと。

### `client/.env.example` の `VITE_GRAPHQL_ENDPOINT` はそのまま使えない

`client/.env.example` の `VITE_GRAPHQL_ENDPOINT=/graphql` は、CloudFront 配下で同一オリジンに揃う**本番構成向け**の相対パス。
vite dev サーバには proxy 設定がないため、dev では手順 3 のように**絶対 URL** を指定する必要がある。
`VITE_GRAPHQL_ENDPOINT` を持つのは `client/.env.example` であり、リポジトリルートの `.env.example` には無い。

### vite のポートを変えると CORS で弾かれる

`src/app.setup.ts` は `NODE_ENV=development` のとき `http://localhost:5173` と `http://192.168.1.3:5173` のみを許可する。
vite が別ポート（`5174` など）にフォールバックすると CORS エラーになるため、`5173` が空いていることを確認する。

### 依存更新の検証では `npm ci` を省略しない（ルート / `client/` の両方）

このリポジトリは npm workspaces を使わず、ルート（`package-lock.json`）と `client/`（`client/package-lock.json`）が独立した 2 つの npm プロジェクトになっている。
`npm ci` は片方を実行しても他方には及ばないため、手順 2（ルート）と手順 4（`client/`）でそれぞれ実行する。

`client/node_modules` が lock file と乖離していることがある。
2026-08-10 の検証時は `client/package-lock.json` が mapbox-gl 3.28.0 なのに `node_modules` には 3.10.0 が残っており、`npm ci` なしでは 3.28.0 の検証になっていなかった。

依存更新の検証時は `npm ci` の後に実バージョンを確認すること。

```bash
cd client && node -p "require('./node_modules/mapbox-gl/package.json').version"
```

### `src/graphql/graphql.schema.ts` に差分が出る

dev 起動すると `createGraphqlOptions` の `definitions.path` 設定により、`src/graphql/graphql.schema.ts` が自動生成され直して差分が出る。
コミット前に必ず revert する（手順 6 に含めている）。

### 既知のノイズ（異常ではない）

- ブラウザコンソールの `favicon.ico` 404
- WebGL の `GPU stall due to ReadPixels` 警告（WSL のソフトウェアレンダリング由来）

## Playwright MCP で自動確認する場合

mapbox の `Map` インスタンスは `window` に露出していないため、`map.setZoom()` のような直接操作はできない。
ズーム操作は `.mapboxgl-canvas` に `WheelEvent` を dispatch する方法が有効だった。

描画完了の判定には、コンソールログ `Map layers added successfully.` を待つのが確実。
スクリーンショットはタイル読み込み完了を待ってから撮ること。
