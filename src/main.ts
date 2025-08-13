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

  // origin: リクエスト発信元の情報（スキーム・ホスト名・ポート番号）を示すHTTPヘッダー 例: "https://example.com:8080" のような形式
  // ブラウザがクロスオリジン通信（CORS）時に自動で付与し、サーバー側はこの値をもとにアクセス許可するオリジンかどうかを判定する
  app.enableCors({ // CORSの設定をまとめて渡す
    origin: (origin, callback) => { // origin: リクエスト元 callbak: 判定結果
      // !origin: Originヘッダーが無いリクエスト（サーバー間通信やツール等）はCORSチェックをスキップして許可
      // 許可リストに含まれるオリジンか判定、許可
      if (!origin || allowedOrigins.some(allowed => origin.startsWith(allowed))) {
        callback(null, true); // ← ここで「このoriginは許可！」とCORSミドルウェアに通知
      
        // ↓↓ ここから先はCORSミドルウェア（サーバー側）が自動的に実行する処理 ↓↓
        // サーバーはレスポンスヘッダーに下記を付与する
        //   Access-Control-Allow-Origin: <リクエスト元のorigin>
        //   Access-Control-Allow-Credentials: true
        //   Access-Control-Allow-Methods: GET,POST,OPTIONS
        //   Access-Control-Allow-Headers: Content-Type,Authorization 
        // ブラウザはこれらのヘッダーを受け取り
        // 「このリクエストは許可された！」と判断し、API通信を継続する
        // （もしプリフライトリクエスト（OPTIONS）の場合も、同様にヘッダーを付与してレスポンス）
      
      } else {
        logger.error(`CORS Error: Origin ${origin} not allowed.`);
        callback(new Error('Not allowed by CORS')); // ← ここで「このoriginは拒否！」とCORSミドルウェアに通知
      
        // ↓↓ ここから先はCORSミドルウェア（サーバー側）が自動的に実行する処理 ↓↓
        // サーバーはCORSエラーとしてレスポンスを返す
        // ブラウザは「CORS policyによりブロックされました」というエラーを表示し、API通信は中断される
      }
      
    },
    methods: ['GET', 'POST', 'OPTIONS'], // サーバーが許可するHTTPメソッド（リクエストの種類）を指定
    allowedHeaders: ['Content-Type', 'Authorization'], // 許可するHTTPヘッダーを指定
    credentials: true,
    // Cookieや認証情報を含むリクエストも許可
    // trueにすると、フロントエンドからのログイン状態の維持などが可能になります
  });

  // Readiness health check endpoint for ALB (DB接続や認証とは無関係に200を返す)
  app.use('/health', (req, res) => {
    res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
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
