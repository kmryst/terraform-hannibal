
// C:\code\javascript\nestjs-hannibal-3\src\modules\route\route.service.ts

import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Route } from '../../entities';
import { hannibalRoute } from '../../geojson_data/hannibalRoute';
import { pointRoute } from '../../geojson_data/pointRoute';

@Injectable()
export class RouteService {
  constructor(
    @InjectRepository(Route)
    private routeRepository: Repository<Route>,
  ) {}

  // データベースからルート取得
  async findAll(): Promise<Route[]> {
    return this.routeRepository.find();
  }

  async findOne(id: number): Promise<Route | null> {
    return this.routeRepository.findOne({ where: { id } });
  }

  async create(routeData: Partial<Route>): Promise<Route> {
    const route = this.routeRepository.create(routeData);
    return this.routeRepository.save(route);
  }

  async update(id: number, routeData: Partial<Route>): Promise<Route | null> {
    await this.routeRepository.update(id, routeData);
    return this.findOne(id);
  }

  async remove(id: number): Promise<void> {
    await this.routeRepository.delete(id);
  }

  // 初期データ投入用（後で削除予定）
  async seedInitialData(): Promise<void> {
    const existingRoutes = await this.routeRepository.count();
    if (existingRoutes === 0) {
      await this.routeRepository.save({
        name: 'ハンニバルルート',
        description: 'ハンニバルがアルプスを越えた歴史的ルート',
        coordinates: hannibalRoute.features[0].geometry.coordinates,
        color: '#ff0000',
      });
    }
  }

  // 後方互換性のため残す（段階的に削除）
  getHannibalRoute() {
    return {
      ...hannibalRoute,
      features: hannibalRoute.features.map((feature) => ({
        ...feature,
        geometry: {
          ...feature.geometry,
          coordinates:
            feature.geometry.type === "LineString"
              ? feature.geometry.coordinates
              : [feature.geometry.coordinates],
        },
      })),
    };
  }

  getPointRoute() {
    return pointRoute;
  }
}
