FROM node:23.11.0-alpine3.21
# FROM node:20-alpine
# 「node:20-alpine」という名前の公式Node.jsイメージを使ってDockerコンテナを作り始める、という意味です
# Node.jsのバージョン20が入っていて、Alpine Linuxという軽量なLinuxをベースにしたイメージです

WORKDIR /app
# コンテナの中で作業するディレクトリ（フォルダ）を「/app」に設定します
# 以降のコマンド（COPYやRUNなど）はすべてこの「/app」フォルダ内で実行されます

COPY package*.json ./
# コンテナの「/app」ディレクトリにコピーします
RUN npm ci --omit=dev
# ci: clean install
# 具体的には、まず node_modules フォルダを完全に削除し、package-lock.json に記載された通りのバージョンでパッケージをインストールします
# これにより、開発環境や本番環境、CI（継続的インテグレーション）環境などで、依存パッケージのバージョンのズレを防げます
# package.json と package-lock.json の内容が一致しない場合はエラーになります
# package.jsonには「どのパッケージが必要か」と、その「バージョンの範囲」が書かれています。一方、package-lock.jsonには「実際にインストールされたバージョン」が正確に記録されます

COPY dist ./dist
# ローカル（ホスト）の「dist」フォルダを、コンテナ内の「/app/dist」フォルダにコピーします

# 必要に応じてnode_modules/@nestjs/config等も含める
CMD ["npm", "run", "start:prod"]
# コンテナを起動したときに実行するコマンドを指定しています
# ここでは「npm run start:prod」を実行し、アプリを本番モードで起動します
# CMDはコンテナの「スタートボタン」のようなものです
