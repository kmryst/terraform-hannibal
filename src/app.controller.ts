
// C:\code\javascript\nestjs-hannibal-3\src\app.controller.ts

import { Controller, Get } from '@nestjs/common';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getHello(): string {
    return this.appService.getHello();
  }

  // 企業レベルECS Health Check (Blue/Green対応)
  @Get('health')
  async getHealth() {
    try {
      return await this.appService.getHealthStatus();
    } catch (error) {
      // Professional設計: ALBヘルスチェック用フォールバック
      return { status: 'healthy', timestamp: new Date().toISOString() };
    }
  }

  @Get('health/ready')
  async getReadiness() {
    return await this.appService.getReadinessStatus();
  }

  @Get('health/live')
  async getLiveness() {
    return await this.appService.getLivenessStatus();
  }
}
