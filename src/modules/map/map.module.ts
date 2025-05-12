
// C:\code\javascript\nestjs-hannibal-3\src\modules\map\map.module.ts
// このモジュールで使うリゾルバ（map.resolver.ts）やサービス（map.service.ts）をprovidersとして登録します

import { Module } from '@nestjs/common'; // NestJSの「モジュール」を定義するためのModuleデコレータを読み込んでいる
import { MapResolver } from './map.resolver';
import { MapService } from './map.service';

@Module({
  providers: [MapResolver, MapService], // プロバイダーとは、NestJSが自動的にインスタンス化してくれるクラス（サービスやリゾルバーなど）です
})
export class MapModule {}
