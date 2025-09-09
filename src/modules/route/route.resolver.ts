/**
 * ハンニバルルート GraphQL リゾルバー
 * 
 * GraphQL API のエントリーポイントとして、フロントエンドからの
 * クエリ・ミューテーションリクエストを処理し、ビジネスロジックを
 * RouteService に委譲する役割を担う。
 */

import { Resolver, Query, Mutation, Args, Int } from '@nestjs/graphql';
import { RouteService } from './route.service';
import { Route } from '../../entities';

// GraphQL リゾルバーとして Route エンティティを扱うことを宣言
@Resolver(() => Route)
export class RouteResolver {
  // RouteService を依存性注入で取得
  constructor(private readonly routeService: RouteService) {}

  /**
   * 全ルート取得クエリ
   * PostgreSQL データベースから全てのルートデータを取得
   */
  @Query(() => [Route]) // GraphQL スキーマ: [Route!]! として公開
  async routes(): Promise<Route[]> {
    return this.routeService.findAll();
  }

  /**
   * 特定ルート取得クエリ
   * ID を指定して特定のルートデータを取得
   */
  @Query(() => Route, { nullable: true }) // GraphQL: Route 型、null 許可
  async route(@Args('id', { type: () => Int }) id: number): Promise<Route | null> {
    return this.routeService.findOne(id);
  }

  /**
   * ルート作成ミューテーション
   * 新しいルートデータをデータベースに保存
   */
  @Mutation(() => Route) // GraphQL: Route 型を返すミューテーション
  async createRoute(
    @Args('name') name: string,
    @Args('description') description: string,
    @Args('coordinates', { type: () => [[Number]] }) coordinates: number[][],
    @Args('color', { nullable: true }) color?: string,
  ): Promise<Route> {
    return this.routeService.create({ name, description, coordinates, color });
  }

  /**
   * 初期データ投入ミューテーション
   * ハンニバルのアルプス越えルートの初期データを投入
   */
  @Mutation(() => String) // GraphQL: String 型を返すミューテーション
  async seedRoutes(): Promise<string> {
    await this.routeService.seedInitialData();
    return '初期データを投入しました';
  }

  // --- レガシー API（後方互換性のため保持） ---
  
  /**
   * ハンニバルルート取得（レガシー）
   * @deprecated 新しい routes() クエリを使用してください
   */
  @Query('hannibalRoute')
  getHannibalRoute() {
    return this.routeService.getHannibalRoute();
  }

  /**
   * ポイントルート取得（レガシー）
   * @deprecated 新しい routes() クエリを使用してください
   */
  @Query('pointRoute')
  getPointRoute() {
    return this.routeService.getPointRoute();
  }
}
