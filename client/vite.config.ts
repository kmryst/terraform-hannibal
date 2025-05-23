/* Viteの設定ファイル
 * このファイルでは、Viteのビルド設定や開発サーバーの設定を行います
 */
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  // Reactプラグインを有効化
  plugins: [react()],
  
  // 開発サーバーの設定
  server: {
    port: 5173,  // 開発サーバーのポート番号
    host: true,  // ネットワーク上の他のデバイスからアクセス可能に
  }
});
