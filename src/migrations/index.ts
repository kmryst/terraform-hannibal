import { MigrationInterface } from 'typeorm';
import { InitialSchema1791279966870 } from './1791279966870-InitialSchema';

// 適用対象のマイグレーションを古い順に列挙する。
// migration:generate / migration:create で追加したクラスは、ここにも必ず追記する。
export const migrations: (new () => MigrationInterface)[] = [
  InitialSchema1791279966870,
];
