
// C:\code\javascript\nestjs-hannibal-3\src\modules\route\route.service.ts

import { Injectable } from '@nestjs/common';
import { hannibalRoute } from '../../geojson_data/hannibalRoute';
import { pointRoute } from '../../geojson_data/pointRoute';

@Injectable()
export class RouteService {
  getHannibalRoute() {
    return {
      ...hannibalRoute, // hannibalRoute オブジェクトの内容をすべてコピー
      features: hannibalRoute.features.map((feature) => ({ // 配列featuresのそれぞれの要素featureにmapで処理する 「features:」だけ新しい値で上書きする
        ...feature, // 各feature（地理情報の1つ）をスプレッド構文でコピーします
        geometry: {
          ...feature.geometry,
          coordinates:
            feature.geometry.type === "LineString" // 条件式
              ? feature.geometry.coordinates // trueのときに返す値 なにも修正しない
              : [feature.geometry.coordinates], // falseのときに返す値
        },
      })),
    };
  }

  getPointRoute() {
    return pointRoute;
  }
}
