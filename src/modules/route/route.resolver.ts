
// C:\code\javascript\nestjs-hannibal-1\src\modules\route\route.resolver.ts

import { Resolver, Query, Mutation, Args, Int } from '@nestjs/graphql';
import { RouteService } from './route.service';
import { Route } from '../../entities';

@Resolver(() => Route)
export class RouteResolver {
  constructor(private readonly routeService: RouteService) {}

  // 新しいGraphQLクエリ（データベースから）
  @Query(() => [Route])
  async routes(): Promise<Route[]> {
    return this.routeService.findAll();
  }

  @Query(() => Route, { nullable: true })
  async route(@Args('id', { type: () => Int }) id: number): Promise<Route | null> {
    return this.routeService.findOne(id);
  }

  @Mutation(() => Route)
  async createRoute(
    @Args('name') name: string,
    @Args('description') description: string,
    @Args('coordinates', { type: () => [[Number]] }) coordinates: number[][],
    @Args('color', { nullable: true }) color?: string,
  ): Promise<Route> {
    return this.routeService.create({ name, description, coordinates, color });
  }

  // 初期データ投入用
  @Mutation(() => String)
  async seedRoutes(): Promise<string> {
    await this.routeService.seedInitialData();
    return '初期データを投入しました';
  }

  // 後方互換性のため残す（段階的に削除）
  @Query('hannibalRoute')
  getHannibalRoute() {
    return this.routeService.getHannibalRoute();
  }

  @Query('pointRoute')
  getPointRoute() {
    return this.routeService.getPointRoute();
  }
}
