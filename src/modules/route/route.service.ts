
// C:\code\javascript\nestjs-hannibal-1\src\modules\route\route.service.ts

import { Injectable } from '@nestjs/common';
import { hannibalRoute } from '../../geojson_data/hannibalRoute';
import { pointRoute } from '../../geojson_data/pointRoute';

@Injectable()
export class RouteService {
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
