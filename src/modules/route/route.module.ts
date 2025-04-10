
// C:\code\javascript\nestjs-hannibal-1\src\modules\route\route.module.ts

import { Module } from '@nestjs/common';
import { RouteResolver } from './route.resolver';
import { RouteService } from './route.service';

@Module({
  providers: [RouteResolver, RouteService],
})
export class RouteModule {}
