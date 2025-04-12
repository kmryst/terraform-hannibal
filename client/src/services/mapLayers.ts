
// C:\code\javascript\graphql-react-hannibal-8\src\services\mapLayers.ts


import mapboxgl from "mapbox-gl";

export const addHannibalRouteLayers = (map: mapboxgl.Map, hannibalRouteData: any, pointRouteData: any) => {
  // ソースを追加（全体データ）
  map.addSource("route", {
    type: "geojson",
    data: hannibalRouteData,
  });

  // LineString用セグメント生成
  const coordinates = hannibalRouteData.features[0].geometry.coordinates;
  const segments = [];
  
  for (let i = 0; i < coordinates.length - 1; i++) {
    const width = i === 0 ? 10 : i === 1 ? 7 : 3;

    segments.push({
      type: "Feature",
      geometry: {
        type: "LineString",
        coordinates: [coordinates[i], coordinates[i + 1]],
      },
      properties: { width },
    });
  }

  // セグメント用ソースを追加
  map.addSource("route-segments", {
    type: "geojson",
    data: {
      type: "FeatureCollection",
      // @ts-expect-error: TypeScript
      features: segments,
    },
  });

  // LineStringレイヤー追加
  map.addLayer({
    id: "route-line",
    type: "line",
    source: "route-segments",
    paint: {
      "line-color": "#FF0000",
      "line-width": ["get", "width"],
      "line-opacity": 0.8,
    },
  });

  // ポイントマーカー追加
  map.addSource("point-route", {
    type: "geojson",
    data: pointRouteData,
  });

  map.addLayer({
    id: "route-points",
    type: "circle",
    source: "point-route",
    paint: {
      "circle-radius": 6,
      "circle-color": "#FFFFFF",
      "circle-stroke-width": 2,
      "circle-stroke-color": "#FF0000",
    },
  });

  // ラベル追加
  map.addLayer({
    id: "route-labels",
    type: "symbol",
    source: "point-route",
    layout: {
      "text-field": ["get", "description"],
      "text-variable-anchor": ["top", "bottom", "left", "right"],
      "text-radial-offset": 0.8,
      "text-size": 12,
    },
    paint: {
      "text-color": "#ffffff",
      "text-halo-color": "#000000",
      "text-halo-width": 2,
    },
  });
};





export const addCapitalCityLayers = (map: mapboxgl.Map, capitalCitiesData: any) => {
  
  // ソース追加（首都データ）
  map.addSource("capitals", {
    type: "geojson",
    data: capitalCitiesData,
  });

  // ローマ用アイコン読み込み・登録
  map.loadImage("/taka.png", (error, image) => {
    if (error) throw error;
    // @ts-expect-error: TypeScript
    if (!map.hasImage("roman-icon")) { // 重複登録防止
      map.addImage("roman-icon", image);
    }
  });

  // カルタゴ用アイコン読み込み・登録
  map.loadImage("/zou.png", (error, image) => {
    // @ts-expect-error: TypeScript
    if (error) throw error;
    if (!map.hasImage("carthage-icon")) { // 重複登録防止
      map.addImage("carthage-icon", image);
    }
    
    // アイコンレイヤー追加（アイコンが読み込まれてからレイヤー追加）
    if (!map.getLayer("capital-icons")) { 
      map.addLayer({
        id: "capital-icons",
        type: "symbol",
        source: "capitals",
        layout: {
          "icon-image": [
            "match",
            ["get", "empire"],
            "Roman",       "roman-icon",
            "Carthaginian","carthage-icon",
            /* default */   ""
          ],
          "icon-size": 0.12,
          "icon-allow-overlap": true,
          "icon-ignore-placement": true,

          // テキストラベル設定
          "text-field": ["get", "name"],
          "text-font": ["Open Sans Bold"],
          "text-offset": [0,1],
          "text-anchor":"top"
        },
        paint:{
          'text-color':'#000000',
          'text-halo-color':'#FFFFFF',
          'text-halo-width':1
        }
      });
    }
    
  });
};
