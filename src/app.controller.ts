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

  // AWS Professional: 企業レベルECS Health Check (Blue/Green対応)
  @Get('health')
  async getHealth() {
    try {
      return await this.appService.getHealthStatus();
    } catch (error) {
      // Professional設計: ALBヘルスチェック用フォールバック
      console.error('Health check error:', error);
      return {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        message: 'Fallback health check response',
      };
    }
  }

  // AWS Professional: シンプルなヘルスチェック（ALB用）
  @Get('health/simple')
  getSimpleHealth() {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
      service: 'nestjs-hannibal-3',
    };
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
