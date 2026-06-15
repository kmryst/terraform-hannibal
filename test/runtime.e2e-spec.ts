import { ConfigService } from '@nestjs/config';
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApplication } from '../src/app.setup';

describe('Node 24 / Express 5 / Apollo Server 5 runtime', () => {
  let app: INestApplication;
  const originalEnv = {
    nodeEnv: process.env.NODE_ENV,
    devClientUrlLocal: process.env.DEV_CLIENT_URL_LOCAL,
    devClientUrlIp: process.env.DEV_CLIENT_URL_IP,
  };

  function restoreEnv(name: string, value: string | undefined): void {
    if (value === undefined) {
      delete process.env[name];
      return;
    }

    process.env[name] = value;
  }

  beforeAll(async () => {
    if (!process.env.DATABASE_URL) {
      throw new Error(
        'DATABASE_URL is required for AppModule end-to-end tests',
      );
    }

    process.env.NODE_ENV = 'development';
    process.env.DEV_CLIENT_URL_LOCAL = 'http://localhost:5173';
    process.env.DEV_CLIENT_URL_IP = 'http://127.0.0.1:5173';

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    configureApplication(app, app.get(ConfigService));
    await app.init();
  });

  afterAll(async () => {
    try {
      await app.close();
    } finally {
      restoreEnv('NODE_ENV', originalEnv.nodeEnv);
      restoreEnv('DEV_CLIENT_URL_LOCAL', originalEnv.devClientUrlLocal);
      restoreEnv('DEV_CLIENT_URL_IP', originalEnv.devClientUrlIp);
    }
  });

  it('serves the root and health endpoints', async () => {
    await request(app.getHttpServer()).get('/').expect(200, 'Hello World!');

    const health = await request(app.getHttpServer())
      .get('/health')
      .expect(200);
    expect(health.body).toMatchObject({ status: 'ok' });
    expect(new Date(health.body.timestamp).toString()).not.toBe('Invalid Date');
  });

  it('serves GraphiQL in development', async () => {
    const response = await request(app.getHttpServer())
      .get('/graphql')
      .set('Accept', 'text/html')
      .expect(200);

    expect(response.text).toContain('graphiql');
  });

  it('accepts frontend JSON GraphQL requests with CSRF prevention enabled', async () => {
    const response = await request(app.getHttpServer())
      .post('/graphql')
      .set('Origin', 'http://localhost:5173')
      .set('Content-Type', 'application/json')
      .send({ query: '{ capitalCities { type } }' })
      .expect(200)
      .expect('Access-Control-Allow-Origin', 'http://localhost:5173');

    expect(response.body.errors).toBeUndefined();
    expect(response.body.data.capitalCities.type).toBe('FeatureCollection');
  });

  it('wires the Route resolver to the TypeORM repository', async () => {
    const response = await request(app.getHttpServer())
      .post('/graphql')
      .set('Content-Type', 'application/json')
      .send({ query: '{ routes { id } }' })
      .expect(200);

    expect(response.body).toEqual({ data: { routes: [] } });
  });

  it('rejects a simple GraphQL GET that can bypass preflight', async () => {
    const response = await request(app.getHttpServer())
      .get('/graphql')
      .query({ query: '{ __typename }' })
      .set('Accept', 'application/json')
      .expect(400);

    expect(response.body.errors[0].message).toContain('CSRF');
  });

  it('allows configured CORS origins and rejects lookalike origins', async () => {
    await request(app.getHttpServer())
      .options('/graphql')
      .set('Origin', 'http://localhost:5173')
      .set('Access-Control-Request-Method', 'POST')
      .expect(204)
      .expect('Access-Control-Allow-Origin', 'http://localhost:5173');

    await request(app.getHttpServer())
      .options('/graphql')
      .set('Origin', 'http://localhost:5173.example.com')
      .set('Access-Control-Request-Method', 'POST')
      .expect(500);
  });
});
