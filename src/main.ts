// C:\code\javascript\nestjs-hannibal-3\src\main.ts
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ConfigService } from '@nestjs/config';
import { Logger } from '@nestjs/common'; // Loggerを追加 ログ出力用クラス

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const configService = app.get(ConfigService);
  const logger = new Logger('Bootstrap'); // Loggerインスタンスを作成 BootstrapはこのLoggerを識別するためのラベル

  const port = configService.get<number>('PORT', 3000); // .env, process.env から取得する
  const host = configService.get<string>('HOST', '0.0.0.0');
  const nodeEnv = configService.get<string>('NODE_ENV', 'development');

  let allowedOrigins: string[] = []; // 許可するオリジンのリスト どのサイトからのアクセスを許可するか

  if (nodeEnv === 'production') {
    const clientUrl = configService.get<string>('CLIENT_URL'); // 本番用フロントエンドURL
    if (clientUrl) {
      allowedOrigins.push(clientUrl);
      // allowedOrigins という配列に、clientUrl を追加して、アクセスを許可する CORS
      logger.log(`Production CORS: Allowing origin: ${clientUrl}`);
      // ログを出力＝記録している
    } else {
      logger.warn('Production CORS: CLIENT_URL environment variable is not set. No external origins will be allowed');
      // 警告、記録している
      // external: 外部
      // 必要であれば、ここでデフォルトの挙動（エラーにするなど）を定義
    }
  } else {
    // 開発環境の場合は、既存の .env で定義されているローカル開発用URLを許可
    const devClientUrlLocal = configService.get<string>('DEV_CLIENT_URL_LOCAL', 'http://localhost:5173');
    const devClientUrlIp = configService.get<string>('DEV_CLIENT_URL_IP', 'http://192.168.1.3:5173');
    allowedOrigins = [devClientUrlLocal, devClientUrlIp];
    logger.log(`Development CORS: Allowing origins: ${allowedOrigins.join(', ')}`);
    // .joinで配列の要素をすべて結合して、間にカンマを入れる
  }

  app.enableCors({ // CORSの設定をまとめて渡す
    origin: (origin, callback) => { // origin: アクセス元 callbak: 判定結果
      // originがないリクエスト (サーバー間通信やツール) や、許可リストに含まれるオリジンを許可
      if (!origin || allowedOrigins.some(allowed => origin.startsWith(allowed))) {
        // allowed: allowedOrigins配列の中の各要素（1つ1つのURL）が順番に入る ループ処理
        // .some: 配列の中に条件を満たす要素が1つでもあればtrueを返す
        // .startsWith: origin が、allowed ではじまっているか
        // allowedOrigins配列の中に、originがその値で始まるものが1つでもあればtrueを返す
        callback(null, true);
        // 許可する場合はcallbackの第1引数にnull（エラーなし）、第2引数にtrueを渡す
      } else {
        logger.error(`CORS Error: Origin ${origin} not allowed.`);
        callback(new Error('Not allowed by CORS'));
      }
    },
    methods: ['GET', 'POST', 'OPTIONS'], // サーバーが許可するHTTPメソッド（リクエストの種類）を指定
    allowedHeaders: ['Content-Type', 'Authorization'], // 許可するHTTPヘッダーを指定
    credentials: true,
    // Cookieや認証情報を含むリクエストも許可
    // trueにすると、フロントエンドからのログイン状態の維持などが可能になります
  });

  await app.listen(port, host, () => { // await: サーバが起動するまで次の処理を待つ 
    logger.log(`🚀 Server ready at http://${host}:${port}/graphql`);
    logger.log(`Environment: ${nodeEnv}`);
    if (allowedOrigins.length > 0) {
      logger.log(`Allowed CORS origins: ${allowedOrigins.join(', ')}`);
    } else {
      logger.log('No origins explicitly allowed by CORS.'); // explicitly: 明確に
    }
  });
}
bootstrap();
