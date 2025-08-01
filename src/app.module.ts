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
import { AppController } from './app.controller';
import { AppService } from './app.service';

@Module({
  imports: [
    ConfigModule.forRoot({
      // forRoot: アプリ全体で一度だけ初期化するというほどの意味
      isGlobal: true,
    }),
    TypeOrmModule.forRoot({
      type: 'postgres',
      url: process.env.DATABASE_URL,
      host: process.env.DB_HOST,
      port: parseInt(process.env.DB_PORT) || 5432,
      username: process.env.DB_USERNAME,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
      entities: [Route],
      synchronize: process.env.NODE_ENV !== 'production',
      logging: ['error', 'warn'],
      retryAttempts: 5,
      retryDelay: 3000,
      autoLoadEntities: true,
      keepConnectionAlive: true,
      connectTimeoutMS: 30000,
      ssl: {
        rejectUnauthorized: false
      }
    }),
    TypeOrmModule.forFeature([Route]), // AWS Professional: Repository注入用
    GraphQLModule.forRoot<ApolloDriverConfig>({
      driver: ApolloDriver,
      typePaths: ['./**/*.graphql'],
      path: '/api/graphql',
      definitions: {
        path: join(process.cwd(), 'src/graphql/graphql.schema.ts'),
      },
      context: ({ req }) => ({ req }),
      csrfPrevention: false,
      playground: true,
      introspection: true,
      cors: {
        origin: process.env.CLIENT_URL || 'https://hamilcar-hannibal.click',
        credentials: true,
      },
      formatError: (error) => {
        console.error('GraphQL Error:', error);
        return error;
      },
    }),
    MapModule,
    RouteModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}


