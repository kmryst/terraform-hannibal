# 1. ビルド用ステージ
# dockerfile-utils: ignore
FROM node:20-alpine AS builder

WORKDIR /usr/src/app

# 依存関係インストール
COPY package*.json ./
RUN npm ci

# アプリケーションのソースをコピー
COPY . .

# Nest CLIでビルド
RUN npm run build

# 2. 本番用ステージ
FROM node:20-alpine

WORKDIR /usr/src/app

# RDS CA証明書をダウンロード
RUN apk add --no-cache wget && \
    wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem -O /opt/rds-ca-2019-root.pem && \
    apk del wget

# 本番依存のみインストール
COPY package*.json ./
RUN npm ci --omit=dev

# distディレクトリとnode_modulesをコピー
COPY --from=builder /usr/src/app/dist ./dist
COPY --from=builder /usr/src/app/src ./src
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY --from=builder /usr/src/app/.env ./

ENV NODE_ENV=production
ENV PORT=3000
ENV HOST=0.0.0.0

EXPOSE 3000

CMD ["node", "dist/main.js"]
