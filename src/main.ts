import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { configureApplication } from './app.setup';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const configService = app.get(ConfigService);
  const logger = new Logger('Bootstrap');
  const port = configService.get<number>('PORT', 3000);
  const host = configService.get<string>('HOST', '0.0.0.0');
  const nodeEnv = configService.get<string>('NODE_ENV', 'development');
  const allowedOrigins = configureApplication(app, configService, logger);

  await app.listen(port, host, () => {
    logger.log(`Server ready at http://${host}:${port}/graphql`);
    logger.log(`Environment: ${nodeEnv}`);
    logger.log(
      allowedOrigins.length > 0
        ? `Allowed CORS origins: ${allowedOrigins.join(', ')}`
        : 'No origins explicitly allowed by CORS.',
    );
  });
}

void bootstrap();
