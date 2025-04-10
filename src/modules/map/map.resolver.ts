
// C:\code\javascript\nestjs-hannibal-1\src\modules\map\map.resolver.ts

import { Resolver, Query } from '@nestjs/graphql';
import { MapService } from './map.service';

@Resolver()
export class MapResolver {
  constructor(private readonly mapService: MapService) {}

  @Query('capitalCities')
  getCapitalCities() {
    return this.mapService.getCapitalCities();
  }
}
