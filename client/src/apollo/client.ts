// C:\code\javascript\nestjs-hannibal-3\client\src\apollo\client.ts
import { ApolloClient, HttpLink, InMemoryCache } from "@apollo/client";

// Viteの環境変数からエンドポイントを取得 (プレフィックス 'VITE_' が必要)
const graphqlUri = import.meta.env.VITE_GRAPHQL_ENDPOINT;

if (!graphqlUri) {
  console.error("ERROR: VITE_GRAPHQL_ENDPOINT is not defined in your environment variables (.env.* file).");
  // フォールバックを設定するか、エラーを発生させる
}

console.log(`[Apollo Client] Connecting to GraphQL at: ${graphqlUri}`);

// Apollo Client 4 は `uri` ショートハンドを廃止し、`link` を必須オプションにした。
// 挙動は 3 系の `uri` 指定と等価（内部で HttpLink を生成していた）。
const client = new ApolloClient({
   link: new HttpLink({
     uri: graphqlUri || '/graphql', // 環境変数が未定義の場合のフォールバック例
   }),
   cache: new InMemoryCache(),
 });

 export default client;
