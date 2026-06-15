# 1. ビルド用ステージ
# dockerfile-utils: ignore
FROM node:24-alpine AS builder

WORKDIR /usr/src/app

# 依存関係インストール
COPY package*.json ./
RUN npm ci

# アプリケーションのソースをコピー
COPY . .

# Nest CLIでビルド
RUN npm run build

# 2. 本番用ステージ
FROM node:24-alpine

WORKDIR /usr/src/app

# RDS CA証明書をダウンロード
RUN apk add --no-cache wget && \
    wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem -O /opt/rds-ca-2019-root.pem && \
    chmod 644 /opt/rds-ca-2019-root.pem && \
    apk del wget

# 本番依存のみインストール
COPY package*.json ./
RUN npm ci --omit=dev

# コンパイル済み JS
COPY --from=builder /usr/src/app/dist ./dist

# Apollo Server schema-first: typePaths が ./**/*.graphql をランタイムに読む
COPY --from=builder /usr/src/app/src/graphql/schema ./src/graphql/schema

ENV NODE_ENV=production
ENV PORT=3000
ENV HOST=0.0.0.0

EXPOSE 3000

USER node

CMD ["node", "dist/main.js"]
