
// C:\code\javascript\nestjs-hannibal-3\src\common\interfaces\geo.interface.ts
// この geo.interface.ts ファイルは、GeoJSON形式の地理情報データをTypeScriptの型（インターフェース）としてNestJSプロジェクト内で扱うためのものです

export interface Point {
  type: string;
  coordinates: number[];
}

export interface LineString {
  type: string;
  coordinates: number[][];
}

export interface CapitalCityProperties {
  name: string;
  description: string;
  empire: string;
}

export interface RouteProperties {
  description: string;
}

export interface GeoFeature<G, P> {
  type: string;
  geometry: G;
  properties: P;
}

export interface GeoCollection<F> {
  type: string;
  features: F[];
}
