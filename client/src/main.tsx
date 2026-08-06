

// main.tsx

// import React from 'react';
// import { StrictMode } from 'react';
// import { createRoot } from 'react-dom/client';
// import './index.css';
// import App from '../App';
// import { ApolloClient, InMemoryCache, ApolloProvider } from '@apollo/client';

// // Apollo Client を設定
// const client = new ApolloClient({
//   uri: 'http://localhost:4000/graphql', // GraphQL サーバーのエンドポイント
//   cache: new InMemoryCache(), // キャッシュ設定
// });

// // React アプリケーションをレンダリング
// createRoot(document.getElementById('root')!).render(
//   <StrictMode>
//     {/* ApolloProvider でアプリ全体をラップ */}
//     <ApolloProvider client={client}>
//       <App />
//     </ApolloProvider>
//   </StrictMode>
// );



import React from 'react';
import ReactDOM from 'react-dom/client';
// Apollo Client 4 で React 向けの export は '@apollo/client/react' へ移動した
import { ApolloProvider } from '@apollo/client/react';
import client from './apollo/client';
import App from './App';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ApolloProvider client={client}>
      <App />
    </ApolloProvider>
  </React.StrictMode>,
);
