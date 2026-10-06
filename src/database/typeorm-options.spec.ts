import { InitialSchema1791279966870 } from '../migrations/1791279966870-InitialSchema';
import {
  buildDatabaseUrlFromParts,
  createTypeOrmOptions,
} from './typeorm-options';

describe('createTypeOrmOptions', () => {
  it.each(['production', 'development', 'test'])(
    'manages the schema only through migrations when NODE_ENV=%s',
    (nodeEnv) => {
      const options = createTypeOrmOptions({ NODE_ENV: nodeEnv });

      expect(options).toMatchObject({
        type: 'postgres',
        synchronize: false,
        migrationsRun: true,
        migrationsTransactionMode: 'all',
      });
      expect(options.migrations).toContain(InitialSchema1791279966870);
    },
  );

  it('logs migration progress in production', () => {
    expect(createTypeOrmOptions({ NODE_ENV: 'production' }).logging).toEqual(
      expect.arrayContaining(['schema', 'migration']),
    );
  });

  it('prefers DATABASE_URL over the individual DB_* variables', () => {
    const options = createTypeOrmOptions({
      DATABASE_URL: 'postgresql://u:p@db:5432/app?sslmode=disable',
      DB_HOST: 'ignored',
      DB_PORT: '5432',
      DB_USER: 'ignored',
      DB_PASSWORD: 'ignored',
      DB_NAME: 'ignored',
    });

    expect(options).toMatchObject({
      url: 'postgresql://u:p@db:5432/app?sslmode=disable',
    });
  });
});

describe('buildDatabaseUrlFromParts', () => {
  it('builds a URL with encoded credentials and TLS parameters', () => {
    expect(
      buildDatabaseUrlFromParts({
        DB_HOST: 'db.example.com',
        DB_PORT: '5432',
        DB_USER: 'app user',
        DB_PASSWORD: 'p@ss/word',
        DB_NAME: 'app',
        DB_SSLROOTCERT: '/opt/ca.pem',
      }),
    ).toBe(
      'postgresql://app%20user:p%40ss%2Fword@db.example.com:5432/app?sslmode=require&sslrootcert=%2Fopt%2Fca.pem',
    );
  });

  it('returns undefined when a part is missing', () => {
    expect(buildDatabaseUrlFromParts({ DB_HOST: 'db' })).toBeUndefined();
  });
});
