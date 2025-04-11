
// C:\code\javascript\nestjs-hannibal-3\src\apollo\client.ts

import { ApolloClient, InMemoryCache } from "@apollo/client";

const client = new ApolloClient({
  uri: "http://localhost:4000/graphql", // NestJSサーバーのGraphQLエンドポイント
  cache: new InMemoryCache(),
});

export default client;




