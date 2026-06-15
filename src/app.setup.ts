import { INestApplication, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Request, Response } from 'express';

export function configureApplication(
  app: INestApplication,
  configService: ConfigService,
  logger = new Logger('Bootstrap'),
): string[] {
  const nodeEnv = configService.get<string>('NODE_ENV', 'development');
  let allowedOrigins: string[] = [];

  if (nodeEnv === 'production') {
    const clientUrl = configService.get<string>('CLIENT_URL');
    if (clientUrl) {
      allowedOrigins.push(clientUrl);
      logger.log(`Production CORS: Allowing origin: ${clientUrl}`);
    } else {
      logger.warn(
        'Production CORS: CLIENT_URL environment variable is not set. No external origins will be allowed',
      );
    }
  } else {
    const devClientUrlLocal = configService.get<string>(
      'DEV_CLIENT_URL_LOCAL',
      'http://localhost:5173',
    );
    const devClientUrlIp = configService.get<string>(
      'DEV_CLIENT_URL_IP',
      'http://192.168.1.3:5173',
    );
    allowedOrigins = [devClientUrlLocal, devClientUrlIp];
    logger.log(
      `Development CORS: Allowing origins: ${allowedOrigins.join(', ')}`,
    );
  }

  app.enableCors({
    origin: (origin, callback) => {
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
        return;
      }

      logger.error(`CORS Error: Origin ${origin} not allowed.`);
      callback(new Error('Not allowed by CORS'));
    },
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
  });

  app.use('/health', (_req: Request, res: Response) => {
    res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
  });

  return allowedOrigins;
}
