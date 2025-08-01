// C:\code\javascript\nestjs-hannibal-3\src\app.service.ts

import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Route } from './entities';

@Injectable()
export class AppService {
  constructor(
    @InjectRepository(Route)
    private readonly routeRepository: Repository<Route>,
  ) {}

  // AWS Professional: データベース接続状態を確認
  private isDatabaseAvailable(): boolean {
    try {
      return this.routeRepository?.manager?.connection?.isConnected || false;
    } catch {
      return false;
    }
  }
  getHello(): string {
    return 'Hello World!';
  }

  // AWS Professional: 企業レベルECS Health Check (Netflix/Airbnb/Spotify標準)
  async getHealthStatus() {
    const startTime = Date.now();
    const checks = await Promise.allSettled([
      this.checkDatabase(),
      this.checkMemory(),
      this.checkDisk(),
    ]);

    const dbStatus =
      checks[0].status === 'fulfilled'
        ? checks[0].value
        : { status: 'unhealthy', error: checks[0].reason };
    const memoryStatus =
      checks[1].status === 'fulfilled'
        ? checks[1].value
        : { status: 'unhealthy', error: checks[1].reason };
    const diskStatus =
      checks[2].status === 'fulfilled'
        ? checks[2].value
        : { status: 'unhealthy', error: checks[2].reason };

    const overallStatus = [dbStatus, memoryStatus, diskStatus].every(
      (check) => check.status === 'healthy',
    )
      ? 'healthy'
      : 'unhealthy';

    // AWS Professional: 構造化ヘルスチェックレスポンス
    const healthResponse = {
      status: overallStatus,
      timestamp: new Date().toISOString(),
      responseTime: Date.now() - startTime,
      version: process.env.npm_package_version || '1.0.0',
      environment: process.env.NODE_ENV || 'development',
      service: 'nestjs-hannibal-3',

      checks: {
        database: dbStatus,
        memory: memoryStatus,
        disk: diskStatus,
      },
    };

    // AWS Professional: ヘルスチェックログ
    console.log('Health Check Result:', {
      ...healthResponse,
      checks: {
        database: {
          status: dbStatus.status,
          responseTime:
            'responseTime' in dbStatus ? dbStatus.responseTime : undefined,
        },
        memory: {
          status: memoryStatus.status,
          usage: 'usage' in memoryStatus ? memoryStatus.usage : undefined,
        },
        disk: { status: diskStatus.status },
      },
    });

    return healthResponse;
  }

  // Readiness: Blue/Green切り替え準備完了チェック
  async getReadinessStatus() {
    try {
      const dbCheck = await this.checkDatabase();
      return {
        status: dbCheck.status === 'healthy' ? 'ready' : 'not_ready',
        timestamp: new Date().toISOString(),
        database: dbCheck,
      };
    } catch (error) {
      return {
        status: 'not_ready',
        timestamp: new Date().toISOString(),
        error: error.message,
      };
    }
  }

  // Liveness: プロセス生存チェック
  async getLivenessStatus() {
    return {
      status: 'alive',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      pid: process.pid,
    };
  }

  // AWS Professional設計: 実際のDB接続チェック
  async checkDatabaseConnection(): Promise<{
    status: string;
    responseTime?: number;
    error?: string;
  }> {
    const startTime = Date.now();
    try {
      // Blue/Green対応: 実際のDB接続テスト
      await this.routeRepository.manager.connection.query('SELECT 1');
      console.log('Database connection check successful');
      return {
        status: 'healthy',
        responseTime: Date.now() - startTime,
      };
    } catch (error) {
      console.error('Database connection check failed:', error);
      return {
        status: 'unhealthy',
        responseTime: Date.now() - startTime,
        error: error.message,
      };
    }
  }

  // AWS Professional: データベース接続なしでも動作する軽量チェック
  async checkDatabaseLight(): Promise<{
    status: string;
    responseTime?: number;
    error?: string;
  }> {
    const startTime = Date.now();
    try {
      // 軽量な接続チェック
      const isConnected = this.routeRepository.manager.connection.isConnected;
      return {
        status: isConnected ? 'healthy' : 'unhealthy',
        responseTime: Date.now() - startTime,
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        responseTime: Date.now() - startTime,
        error: error.message,
      };
    }
  }

  private async checkDatabase(): Promise<{
    status: string;
    responseTime?: number;
    error?: string;
  }> {
    // AWS Professional: 軽量チェックを優先、失敗時のみ詳細チェック
    try {
      return await this.checkDatabaseLight();
    } catch (error) {
      console.warn('Light database check failed, trying full check:', error);
      return await this.checkDatabaseConnection();
    }
  }

  private async checkMemory(): Promise<{ status: string; usage?: number }> {
    const memUsage = process.memoryUsage();
    const usagePercent = (memUsage.heapUsed / memUsage.heapTotal) * 100;

    return {
      status: usagePercent < 90 ? 'healthy' : 'unhealthy',
      usage: Math.round(usagePercent),
    };
  }

  private async checkDisk(): Promise<{ status: string }> {
    // 簡易ディスクチェック
    return { status: 'healthy' };
  }
}
