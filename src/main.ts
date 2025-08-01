// C:\code\javascript\nestjs-hannibal-3\src\main.ts
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ConfigService } from '@nestjs/config';
import { Logger } from '@nestjs/common'; // Loggerを追加 ログ出力用クラス

async function bootstrap() {
  try {
    const app = await NestFactory.create(AppModule);
    const configService = app.get(ConfigService);
    const logger = new Logger('Bootstrap'); // Loggerインスタンスを作成 BootstrapはこのLoggerを識別するためのラベル

    const port = configService.get<number>('PORT', 3000); // .env, process.env から取得する
    const host = configService.get<string>('HOST', '0.0.0.0');
    const nodeEnv = configService.get<string>('NODE_ENV', 'development');

    // AWS Professional: 環境別CORS設定
    let allowedOrigins: string[] = [];

    if (nodeEnv === 'production') {
      const clientUrl = configService.get<string>('CLIENT_URL');
      if (clientUrl) {
        allowedOrigins = [clientUrl];
        logger.log(`Production CORS: ${clientUrl}`);
      } else {
        // フォールバック: 本番環境でもCORSを有効にする
        allowedOrigins = ['https://hamilcar-hannibal.click'];
        logger.warn('Production: CLIENT_URL not set, using fallback CORS');
      }
    } else {
      allowedOrigins = [
        configService.get<string>(
          'DEV_CLIENT_URL_LOCAL',
          'http://localhost:5173',
        ),
        configService.get<string>(
          'DEV_CLIENT_URL_IP',
          'http://192.168.1.3:5173',
        ),
      ];
      logger.log(`Development CORS: ${allowedOrigins.join(', ')}`);
    }

    // origin: リクエスト発信元の情報（スキーム・ホスト名・ポート番号）を示すHTTPヘッダー 例: "https://example.com:8080" のような形式
    // ブラウザがクロスオリジン通信（CORS）時に自動で付与し、サーバー側はこの値をもとにアクセス許可するオリジンかどうかを判定する
    // AWS Professional: 安定性重視のCORS設定
    app.enableCors({
      origin: allowedOrigins.length > 0 ? allowedOrigins : false,
      methods: ['GET', 'POST', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
      credentials: true,
    });

    // AWS Professional: グローバルエラーハンドリング
    app.useGlobalFilters();
    app.useGlobalInterceptors();

    await app.listen(port, host, () => {
      // await: サーバが起動するまで次の処理を待つ
      logger.log(`🚀 Server ready at http://${host}:${port}/graphql`);
      logger.log(`Environment: ${nodeEnv}`);
      if (allowedOrigins.length > 0) {
        logger.log(`Allowed CORS origins: ${allowedOrigins.join(', ')}`);
      } else {
        logger.log('No origins explicitly allowed by CORS.'); // explicitly: 明確に
      }
    });
  } catch (error) {
    console.error('Failed to start application:', error);
    process.exit(1);
  }
}
bootstrap();
