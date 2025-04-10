
// C:\code\javascript\nestjs-hannibal-1\src\common\interfaces\geo.interface.ts

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
