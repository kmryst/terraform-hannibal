
/**
 * ハンニバルルートサービス
 * 
 * ルートデータのビジネスロジックを担当するサービスクラス。
 * PostgreSQL データベースとのデータ操作、ビジネスルールの適用、
 * レガシーデータとの互換性維持を行う。
 */

import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Route } from '../../entities';
import { hannibalRoute } from '../../geojson_data/hannibalRoute';
import { pointRoute } from '../../geojson_data/pointRoute';

// NestJS の依存性注入コンテナに登録するサービスクラス
@Injectable()
export class RouteService {
  /**
   * コンストラクタ
   * TypeORM Repository を依存性注入で取得
   */
  constructor(
    @InjectRepository(Route) // Route エンティティ用の Repository を注入
    private routeRepository: Repository<Route>,
  ) {}

  /**
   * 全ルート取得
   * データベースから全てのルートデータを取得する
   */
  async findAll(): Promise<Route[]> {
    return this.routeRepository.find();
  }

  /**
   * 特定ルート取得
   * ID を指定して特定のルートデータを取得する
   */
  async findOne(id: number): Promise<Route | null> {
    return this.routeRepository.findOne({ where: { id } });
  }

  /**
   * ルート作成
   * 新しいルートデータをデータベースに保存する
   */
  async create(routeData: Partial<Route>): Promise<Route> {
    const route = this.routeRepository.create(routeData);
    return this.routeRepository.save(route);
  }

  /**
   * ルート更新
   * 指定されたIDのルートデータを更新する
   */
  async update(id: number, routeData: Partial<Route>): Promise<Route | null> {
    await this.routeRepository.update(id, routeData);
    return this.findOne(id);
  }

  /**
   * ルート削除
   * 指定されたIDのルートデータを削除する
   */
  async remove(id: number): Promise<void> {
    await this.routeRepository.delete(id);
  }

  /**
   * 初期データ投入
   * データベースが空の場合、ハンニバルのアルプス越えルートを投入する
   */
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

  /**
   * ハンニバルルート取得（レガシー）
   * 旧フロントエンドとの互換性のために GeoJSON 形式で返却
   * @deprecated 新しい findAll() メソッドを使用してください
   */
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

  /**
   * ポイントルート取得（レガシー）
   * 旧フロントエンドとの互換性のために GeoJSON 形式で返却
   * @deprecated 新しい findAll() メソッドを使用してください
   */
  getPointRoute() {
    return pointRoute;
  }
}
