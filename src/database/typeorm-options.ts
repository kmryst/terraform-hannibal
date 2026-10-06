import { DataSourceOptions } from 'typeorm';
import { Route } from '../entities';
import { migrations } from '../migrations';

type Environment = Record<string, string | undefined>;

export function buildDatabaseUrlFromParts(
  env: Environment = process.env,
): string | undefined {
  const host = env.DB_HOST;
  const port = env.DB_PORT;
  const user = env.DB_USER;
  const password = env.DB_PASSWORD;
  const dbname = env.DB_NAME;

  if (!host || !port || !user || !password || !dbname) return undefined;

  const sslmode = env.DB_SSLMODE ?? 'require';
  const sslrootcert = env.DB_SSLROOTCERT;

  const encodedUser = encodeURIComponent(user);
  const encodedPassword = encodeURIComponent(password);

  const query = new URLSearchParams();
  if (sslmode) query.set('sslmode', sslmode);
  if (sslrootcert) query.set('sslrootcert', sslrootcert);

  return `postgresql://${encodedUser}:${encodedPassword}@${host}:${port}/${dbname}?${query.toString()}`;
}

/**
 * アプリ（TypeOrmModule）と TypeORM CLI（src/database/data-source.ts）が共有する接続設定。
 *
 * スキーマは全環境で TypeORM migrations だけで管理する（ADR 0035）。
 * - synchronize は全環境で無効にする。エンティティからスキーマを自動で書き換えない
 * - migrationsRun により、起動時に未適用のマイグレーションを 1 つのトランザクションで適用する
 * - migrations はクラスを明示的に列挙する（src/migrations/index.ts）。glob を使わないため、
 *   ts（ts-node / ts-jest）と dist（nest build の出力）のどちらでも同じ解決になる
 */
export function createTypeOrmOptions(
  env: Environment = process.env,
): DataSourceOptions {
  return {
    type: 'postgres',
    url: env.DATABASE_URL ?? buildDatabaseUrlFromParts(env),
    entities: [Route],
    migrations,
    migrationsRun: true,
    migrationsTransactionMode: 'all',
    synchronize: false,
    // 'schema' はマイグレーションの適用状況（適用件数、"No migrations are pending" など）を出力する
    logging:
      env.NODE_ENV === 'development' ? 'all' : ['error', 'schema', 'migration'],
  };
}
