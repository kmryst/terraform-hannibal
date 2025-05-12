
// C:\code\javascript\nestjs-hannibal-3\src\modules\map\map.service.ts
// ビジネスロジック・データ取得担当（実際の処理）

import { Injectable } from '@nestjs/common';
import { capitalCities } from '../../geojson_data/capitalCities';

@Injectable()
export class MapService {
  getCapitalCities() {
    return capitalCities;
  }
}
