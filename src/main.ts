// C:\code\javascript\nestjs-hannibal-3\src\main.ts
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ConfigService } from '@nestjs/config';
import { Logger } from '@nestjs/common'; // Loggerを追加

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const configService = app.get(ConfigService);
  const logger = new Logger('Bootstrap'); // Loggerインスタンスを作成

  const port = configService.get<number>('PORT', 3000);
  const host = configService.get<string>('HOST', '0.0.0.0');
  const nodeEnv = configService.get<string>('NODE_ENV', 'development');

  let allowedOrigins: string[] = []; // 許可するオリジンのリスト

  if (nodeEnv === 'production') {
    const clientUrl = configService.get<string>('CLIENT_URL'); // 本番用フロントエンドURL
    if (clientUrl) {
      allowedOrigins.push(clientUrl);
      logger.log(`Production CORS: Allowing origin: ${clientUrl}`);
    } else {
      logger.warn('Production CORS: CLIENT_URL environment variable is not set. No external origins will be allowed.');
      // 必要であれば、ここでデフォルトの挙動（エラーにするなど）を定義
    }
  } else {
    // 開発環境の場合は、既存の .env で定義されているローカル開発用URLを許可
    const devClientUrlLocal = configService.get<string>('DEV_CLIENT_URL_LOCAL', 'http://localhost:5173');
    const devClientUrlIp = configService.get<string>('DEV_CLIENT_URL_IP', 'http://192.168.1.3:5173');
    allowedOrigins = [devClientUrlLocal, devClientUrlIp];
    logger.log(`Development CORS: Allowing origins: ${allowedOrigins.join(', ')}`);
  }

  app.enableCors({
    origin: (origin, callback) => {
      // originがないリクエスト (サーバー間通信やツール) や、許可リストに含まれるオリジンを許可
      if (!origin || allowedOrigins.some(allowed => origin.startsWith(allowed))) {
        callback(null, true);
      } else {
        logger.error(`CORS Error: Origin ${origin} not allowed.`);
        callback(new Error('Not allowed by CORS'));
      }
    },
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
  });

  await app.listen(port, host, () => {
    logger.log(`🚀 Server ready at http://${host}:${port}/graphql`);
    logger.log(`Environment: ${nodeEnv}`);
    if (allowedOrigins.length > 0) {
      logger.log(`Allowed CORS origins: ${allowedOrigins.join(', ')}`);
    } else {
      logger.log('No origins explicitly allowed by CORS.');
    }
  });
}
bootstrap();

