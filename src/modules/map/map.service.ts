
// C:\code\javascript\nestjs-hannibal-1\src\modules\map\map.service.ts

import { Injectable } from '@nestjs/common';
import { capitalCities } from '../../geojson_data/capitalCities';

@Injectable()
export class MapService {
  getCapitalCities() {
    return capitalCities;
  }
}
