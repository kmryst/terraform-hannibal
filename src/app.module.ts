// C:\code\javascript\nestjs-hannibal-3\src\app.module.ts
import { DynamicModule, Module } from '@nestjs/common';
import { GraphQLModule } from '@nestjs/graphql';
import { ApolloDriver, ApolloDriverConfig } from '@nestjs/apollo';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { join } from 'path';
import { MapModule } from './modules/map/map.module';
import { RouteModule } from './modules/route/route.module';
import { createTypeOrmOptions } from './database/typeorm-options';
import { AppController } from './app.controller';
import { AppService } from './app.service';

export function createGraphqlOptions(
  nodeEnv: string,
): Omit<ApolloDriverConfig, 'driver'> {
  const isDevelopment = nodeEnv !== 'production';

  return {
    typePaths: ['./**/*.graphql'],
    path: '/graphql',
    // definitions.path はスキーマからTS型を生成する開発用機能。
    // 本番イメージではsrc/がread-onlyでEACCESになるため開発時のみ有効化する。
    ...(isDevelopment && {
      definitions: {
        path: join(process.cwd(), 'src/graphql/graphql.schema.ts'),
      },
    }),
    context: ({ req }) => ({ req }),
    csrfPrevention: true,
    graphiql: isDevelopment,
    introspection: isDevelopment,
  };
}

export function createGraphqlModule(): DynamicModule {
  return GraphQLModule.forRootAsync<ApolloDriverConfig>({
    driver: ApolloDriver,
    inject: [ConfigService],
    useFactory: (configService: ConfigService) =>
      createGraphqlOptions(
        configService.get<string>('NODE_ENV', 'development'),
      ),
  });
}

@Module({
  imports: [
    ConfigModule.forRoot({
      // forRoot: アプリ全体で一度だけ初期化するというほどの意味
      isGlobal: true,
    }),
    TypeOrmModule.forRoot(createTypeOrmOptions()),
    createGraphqlModule(),
    MapModule,
    RouteModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
