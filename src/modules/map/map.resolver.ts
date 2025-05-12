// C:\code\javascript\nestjs-hannibal-3\src\modules\map\map.resolver.ts
// GraphQLのリクエスト処理担当（APIの窓口）

import { Resolver, Query } from '@nestjs/graphql';
import { MapService } from './map.service';

@Resolver()
export class MapResolver {
  constructor(private readonly mapService: MapService) {}

  @Query('capitalCities') // capitalCitiesという名前のクエリ
  getCapitalCities() { // getCapitalCities(): 今ここで定義したメソッド
    return this.mapService.getCapitalCities();
  }
}
