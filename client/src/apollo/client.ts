
// C:\code\javascript\nestjs-hannibal-1\client\src\apollo\client.ts

/* import { ApolloClient, InMemoryCache } from "@apollo/client";

// localhost ではなく、ローカルIPアドレスを使用
const client = new ApolloClient({
  uri: "https://18.183.38.34:4000/graphql",
  cache: new InMemoryCache(),
});

export default client;


 */




import { ApolloClient, InMemoryCache } from "@apollo/client";

// localhost ではなく、ローカルIPアドレスを使用
const client = new ApolloClient({
   uri: "http://192.168.1.3:4000/graphql",
   cache: new InMemoryCache(),
 });

 export default client;








// import { ApolloClient, InMemoryCache } from "@apollo/client";

// const client = new ApolloClient({
//   uri: "http://localhost:4000/graphql", // NestJSサーバーのGraphQLエンドポイント
//   cache: new InMemoryCache(),
// });

// export default client;






// import { ApolloClient, InMemoryCache } from "@apollo/client";

// const client = new ApolloClient({
//   uri: "http://localhost:4000/graphql", // NestJSサーバーのGraphQLエンドポイント
//   cache: new InMemoryCache(),
// });

// export default client;






// import { ApolloClient, InMemoryCache } from "@apollo/client";

// // localhost ではなく、ローカルIPアドレスを使用
// const client = new ApolloClient({
//   uri: "https://18.179.45.142:4000/graphql", // EC2インスタンスのドメイン
//   cache: new InMemoryCache(),
// });

// export default client;





// import { ApolloClient, InMemoryCache } from "@apollo/client";


// const client = new ApolloClient({
//   uri: process.env.REACT_APP_GRAPHQL_ENDPOINT || "http://192.168.1.3:4000/graphql", 
//   cache: new InMemoryCache(),
// });

// export default client;



