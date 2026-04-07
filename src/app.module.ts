// C:\code\javascript\nestjs-hannibal-3\src\app.module.ts
import { Module } from '@nestjs/common';
import { GraphQLModule } from '@nestjs/graphql';
import { ApolloDriver, ApolloDriverConfig } from '@nestjs/apollo';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { join } from 'path';
import { MapModule } from './modules/map/map.module';
import { RouteModule } from './modules/route/route.module';
import { Route } from './entities';

function buildDatabaseUrlFromParts(): string | undefined {
  const host = process.env.DB_HOST;
  const port = process.env.DB_PORT;
  const user = process.env.DB_USER;
  const password = process.env.DB_PASSWORD;
  const dbname = process.env.DB_NAME;

  if (!host || !port || !user || !password || !dbname) return undefined;

  const sslmode = process.env.DB_SSLMODE ?? 'require';
  const sslrootcert = process.env.DB_SSLROOTCERT;

  const encodedUser = encodeURIComponent(user);
  const encodedPassword = encodeURIComponent(password);

  const query = new URLSearchParams();
  if (sslmode) query.set('sslmode', sslmode);
  if (sslrootcert) query.set('sslrootcert', sslrootcert);

  return `postgresql://${encodedUser}:${encodedPassword}@${host}:${port}/${dbname}?${query.toString()}`;
}

@Module({
  imports: [
    ConfigModule.forRoot({
      // forRoot: アプリ全体で一度だけ初期化するというほどの意味
      isGlobal: true,
    }),
    TypeOrmModule.forRoot({
      type: 'postgres',
      url: process.env.DATABASE_URL ?? buildDatabaseUrlFromParts(),
      entities: [Route],
      synchronize: process.env.NODE_ENV !== 'production', // 本番では false
      logging: process.env.NODE_ENV === 'development',
    }),
    GraphQLModule.forRoot<ApolloDriverConfig>({
      driver: ApolloDriver,
      typePaths: ['./**/*.graphql'],
      path: '/graphql',
      definitions: {
        path: join(process.cwd(), 'src/graphql/graphql.schema.ts'),
      },
      context: ({ req }) => ({ req }),
      csrfPrevention: false,
      playground: true,
      introspection: true,
    }),
    MapModule,
    RouteModule,
  ],
})
export class AppModule {}


