
// C:\code\javascript\nestjs-hannibal-3\src\app.module.ts

import { Module } from '@nestjs/common';
import { GraphQLModule } from '@nestjs/graphql';
import { ApolloDriver, ApolloDriverConfig } from '@nestjs/apollo';
import { ConfigModule } from '@nestjs/config';
import { join } from 'path';
import { MapModule } from './modules/map/map.module';
import { RouteModule } from './modules/route/route.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    GraphQLModule.forRoot<ApolloDriverConfig>({
      driver: ApolloDriver,
      typePaths: ['./**/*.graphql'],
      definitions: {
        path: join(process.cwd(), 'src/graphql/graphql.schema.ts'),
      },
      
      context: ({ req }) => ({ req }),
    }),
    MapModule,
    RouteModule,
  ],
})
export class AppModule {}
