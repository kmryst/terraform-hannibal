
// C:\code\javascript\nestjs-hannibal-1\src\modules\route\route.resolver.ts

import { Resolver, Query } from '@nestjs/graphql';
import { RouteService } from './route.service';

@Resolver()
export class RouteResolver {
  constructor(private readonly routeService: RouteService) {}

  @Query('hannibalRoute')
  getHannibalRoute() {
    return this.routeService.getHannibalRoute();
  }

  @Query('pointRoute')
  getPointRoute() {
    return this.routeService.getPointRoute();
  }
}
