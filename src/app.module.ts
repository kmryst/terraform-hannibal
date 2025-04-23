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
      // forRoot: アプリ全体で一度だけ初期化するというほどの意味
      isGlobal: true,
    }),
    GraphQLModule.forRoot<ApolloDriverConfig>({
      // ApolloDriverConfig は @nestjs/apollo パッケージで定義されている型
      driver: ApolloDriver,
      typePaths: ['./**/*.graphql'],
      // ./**/*.graphql は、プロジェクト内のすべてのサブディレクトリから .graphql 拡張子のファイル（スキーマやクエリ定義）を探す指定です
      definitions: {
        path: join(process.cwd(), 'src/graphql/graphql.schema.ts'),
        // path.join(): 結合する current working directory
        // GraphQLスキーマからTypeScript型定義ファイルを自動生成する設定。
        // path で指定した場所に型定義が出力される
        // スキーマと型定義が自動で同期され、型安全に開発できる
      },
      context: ({ req }) => ({ req }),
      // 「GraphQLのリクエストごとに、どんな情報をコンテキストとして渡すか」を指定しています
    }),
    MapModule,
    RouteModule,
  ],
})
export class AppModule {}
