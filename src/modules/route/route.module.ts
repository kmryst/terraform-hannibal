
// C:\code\javascript\nestjs-hannibal-1\src\modules\route\route.module.ts

import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RouteResolver } from './route.resolver';
import { RouteService } from './route.service';
import { Route } from '../../entities';

@Module({
  imports: [TypeOrmModule.forFeature([Route])],
  providers: [RouteResolver, RouteService],
})
export class RouteModule {}
