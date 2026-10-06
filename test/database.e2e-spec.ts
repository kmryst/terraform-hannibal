import { INestApplication } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { DataSource } from 'typeorm';

// 本番と同じ AppModule（ConfigModule / TypeORM / GraphQL / 各 module）を PostgreSQL に接続して起動し、
// ES Module として配布される @nestjs/* を CommonJS から読み込めること（require(esm)）と、
// GraphQL → TypeORM → PostgreSQL の読み書きを確認する。
// PostgreSQL が必要なため、E2E_DATABASE_URL が未設定のときはスキップする。
// 例: E2E_DATABASE_URL=postgresql://user:pass@localhost:5432/db?sslmode=disable npm run test:e2e
const databaseUrl = process.env.E2E_DATABASE_URL;
const describeWithDatabase = databaseUrl ? describe : describe.skip;

describeWithDatabase('AppModule with PostgreSQL', () => {
  let app: INestApplication;
  let dataSource: DataSource;
  const originalEnv = {
    nodeEnv: process.env.NODE_ENV,
    databaseUrl: process.env.DATABASE_URL,
  };

  function restoreEnv(name: string, value: string | undefined): void {
    if (value === undefined) {
      delete process.env[name];
      return;
    }

    process.env[name] = value;
  }

  async function graphql(query: string, variables?: Record<string, unknown>) {
    const response = await request(app.getHttpServer())
      .post('/graphql')
      .set('Content-Type', 'application/json')
      .send({ query, variables })
      .expect(200);

    expect(response.body.errors).toBeUndefined();
    return response.body.data;
  }

  beforeAll(async () => {
    // AppModule は TypeORM の接続設定を import 時に process.env から読むため、
    // 環境変数を設定してから動的に import する。
    // NODE_ENV が production 以外なので synchronize によりテーブルが作成される。
    process.env.NODE_ENV = 'test';
    process.env.DATABASE_URL = databaseUrl;

    const { AppModule } = await import('../src/app.module');
    const { configureApplication } = await import('../src/app.setup');

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    configureApplication(app, app.get(ConfigService));
    await app.init();

    dataSource = app.get(DataSource);
    await dataSource.query('TRUNCATE TABLE routes RESTART IDENTITY');
  });

  afterAll(async () => {
    try {
      await app?.close();
    } finally {
      restoreEnv('NODE_ENV', originalEnv.nodeEnv);
      restoreEnv('DATABASE_URL', originalEnv.databaseUrl);
    }
  });

  it('starts the full application and serves /health', async () => {
    expect(dataSource.isInitialized).toBe(true);

    const health = await request(app.getHttpServer())
      .get('/health')
      .expect(200);
    expect(health.body).toMatchObject({ status: 'ok' });
  });

  it('seeds the initial route once and reads it back through GraphQL', async () => {
    const seeded = await graphql('mutation { seedRoutes }');
    expect(typeof seeded.seedRoutes).toBe('string');

    // 2 回目は既存データがあるため追加しない
    await graphql('mutation { seedRoutes }');

    const data = await graphql('{ routes { id name coordinates } }');
    expect(data.routes).toHaveLength(1);
    expect(data.routes[0].name).toBe('ハンニバルルート');
    expect(data.routes[0].coordinates.length).toBeGreaterThan(0);
  });

  it('creates a route through GraphQL and persists it in PostgreSQL', async () => {
    const created = await graphql(
      `
        mutation CreateRoute(
          $name: String!
          $description: String!
          $coordinates: [[Float!]!]!
          $color: String
        ) {
          createRoute(
            name: $name
            description: $description
            coordinates: $coordinates
            color: $color
          ) {
            id
            name
            coordinates
            color
            createdAt
          }
        }
      `,
      {
        name: 'e2e route',
        description: 'created by database.e2e-spec.ts',
        coordinates: [
          [12.5, 41.9],
          [10.1, 36.8],
        ],
        color: '#00ff00',
      },
    );

    expect(created.createRoute).toMatchObject({
      name: 'e2e route',
      coordinates: [
        [12.5, 41.9],
        [10.1, 36.8],
      ],
      color: '#00ff00',
    });

    const id = Number(created.createRoute.id);
    const rows = await dataSource.query(
      'SELECT name, coordinates, color FROM routes WHERE id = $1',
      [id],
    );
    expect(rows).toEqual([
      {
        name: 'e2e route',
        coordinates: [
          [12.5, 41.9],
          [10.1, 36.8],
        ],
        color: '#00ff00',
      },
    ]);

    const data = await graphql(
      'query Route($id: Int!) { route(id: $id) { name } }',
      {
        id,
      },
    );
    expect(data.route).toEqual({ name: 'e2e route' });
  });
});
