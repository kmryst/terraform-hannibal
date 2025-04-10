
// C:\code\javascript\nestjs-hannibal-3\src\main.ts

// import { NestFactory } from '@nestjs/core';
// import { AppModule } from './app.module';

// async function bootstrap() {
//   const app = await NestFactory.create(AppModule);

//   // 環境変数からポートとホストを取得
//   const port = process.env.PORT || 4000;
//   const host = process.env.HOST || '0.0.0.0';

//   // CORS設定
//   app.enableCors({
//     origin: ['http://localhost:5173', 'http://192.168.1.3:5173'],
//     credentials: true,
//   });

//   await app.listen(port, host, () => {
//     console.log(`🚀 Server ready at http://${host}:${port}/graphql`);
//   });
// }
// bootstrap();




import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ConfigService } from '@nestjs/config';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  
  const configService = app.get(ConfigService);
  const port = configService.get<number>('PORT', 4000);
  const host = '0.0.0.0'; // すべてのネットワークインターフェースでリッスン
  
  app.enableCors({
    origin: [
      'http://localhost:5173',
      'http://192.168.1.3:5173'
    ],
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true
  });
  
  await app.listen(port, host, () => {
    console.log(`🚀 Server ready at http://${host}:${port}/graphql`);
  });
}
bootstrap();

