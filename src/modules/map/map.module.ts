
// C:\code\javascript\nestjs-hannibal-1\src\modules\map\map.module.ts

import { Module } from '@nestjs/common';
import { MapResolver } from './map.resolver';
import { MapService } from './map.service';

@Module({
  providers: [MapResolver, MapService],
})
export class MapModule {}
