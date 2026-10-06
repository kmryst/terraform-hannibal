import { DataSource } from 'typeorm';
import { createTypeOrmOptions } from './typeorm-options';

// TypeORM CLI（npm run migration:*）が読み込む DataSource。
// アプリと同じ接続設定・エンティティ・マイグレーションを使う。
// 本番イメージでは dist/database/data-source.js を指定して CLI を実行できる。
export default new DataSource(createTypeOrmOptions());
