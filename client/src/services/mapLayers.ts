// C:\code\javascript\nestjs-hannibal-3\client\src\services\mapLayers.ts

// StyleImageInterface のみ mapbox-gl からインポート
import mapboxgl, { StyleImageInterface } from "mapbox-gl";
import * as GeoJSON from 'geojson'; // GeoJSON 型をインポート

// Hannibal ルート関連のレイヤーを追加する関数
export const addHannibalRouteLayers = (map: any, hannibalRouteData: GeoJSON.FeatureCollection<GeoJSON.LineString>, pointRouteData: GeoJSON.FeatureCollection<GeoJSON.Point>) => {
  // データソースが既に追加されていないか確認（重複追加防止）
  if (!map.getSource("route")) {
    map.addSource("route", {
      type: "geojson",
      data: hannibalRouteData,
    });
  }

  // LineString用セグメント生成
  if (hannibalRouteData.features.length > 0 && hannibalRouteData.features[0].geometry.type === "LineString") {
    const coordinates = hannibalRouteData.features[0].geometry.coordinates;
    const segments: GeoJSON.Feature<GeoJSON.LineString, { width: number }>[] = [];

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

    // セグメント用ソースを追加（重複追加防止）
    if (!map.getSource("route-segments")) {
      map.addSource("route-segments", {
        type: "geojson",
        data: {
          type: "FeatureCollection",
          features: segments as GeoJSON.Feature<GeoJSON.Geometry, { width: number }>[],
        },
      });
    }

    // LineStringレイヤー追加（重複追加防止）
    if (!map.getLayer("route-line")) {
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
    }
  } else {
    console.error("Invalid Hannibal route data provided.");
  }

  // ポイントマーカー用ソースを追加（重複追加防止）
  if (!map.getSource("point-route")) {
    map.addSource("point-route", {
      type: "geojson",
      data: pointRouteData,
    });
  }

  // ポイントマーカーレイヤー追加（重複追加防止）
  if (!map.getLayer("route-points")) {
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
  }

  // ラベルレイヤー追加（重複追加防止）
  if (!map.getLayer("route-labels")) {
    map.addLayer({
      id: "route-labels",
      type: "symbol",
      source: "point-route",
      layout: {
        "text-field": ["get", "description"],
        "text-variable-anchor": ["top", "bottom", "left", "right"],
        "text-radial-offset": 0.8,
        "text-size": 12,
        "text-font": ["Open Sans Regular", "Arial Unicode MS Regular"],
      },
      paint: {
        "text-color": "#ffffff",
        "text-halo-color": "#000000",
        "text-halo-width": 1,
      },
    });
  }
};


// 首都関連のレイヤーを追加する関数
export const addCapitalCityLayers = (map: any, capitalCitiesData: GeoJSON.FeatureCollection<GeoJSON.Point, { empire: string; name: string }>) => {

  // 首都データソースを追加（重複追加防止）
  if (!map.getSource("capitals")) {
    map.addSource("capitals", {
      type: "geojson",
      data: capitalCitiesData,
    });
  }

  // アイコン画像を非同期で読み込む Promise を返す関数
  const loadImagePromise = (imagePath: string): Promise<HTMLImageElement | ImageBitmap | ImageData> => {
    return new Promise((resolve, reject) => {
      map.loadImage(imagePath, (error: Error | null, image: HTMLImageElement | ImageBitmap | ImageData | null) => {
        if (error) {
          reject(error);
        } else if (image) {
          resolve(image);
        } else {
          reject(new Error(`Failed to load image ${imagePath} without specific error.`));
        }
      });
    });
  };

  Promise.all([
    loadImagePromise("/taka.png"),
    loadImagePromise("/zou.png")
  ]).then(([romanImage, carthageImage]) => {
    if (!map.hasImage("roman-icon")) {
      map.addImage("roman-icon", romanImage);
    }
    if (!map.hasImage("carthage-icon")) {
      map.addImage("carthage-icon", carthageImage);
    }

    if (!map.getLayer("capital-icons")) {
      map.addLayer({
        id: "capital-icons",
        type: "symbol",
        source: "capitals",
        layout: {
          "icon-image": [
            "match",
            ["get", "empire"],
            "Roman", "roman-icon",
            "Carthaginian", "carthage-icon",
            ""
          ],
          "icon-size": 0.12,
          "icon-allow-overlap": true,
          "icon-ignore-placement": true,
          "text-field": ["get", "name"],
          "text-font": ["Open Sans Bold", "Arial Unicode MS Bold"],
          "text-offset": [0, 1],
          "text-anchor": "top",
          "text-allow-overlap": false,
          "text-ignore-placement": false,
        },
        paint: {
          'text-color': '#000000',
          'text-halo-color': '#FFFFFF',
          'text-halo-width': 1
        }
      });
    }
  }).catch(error => {
    console.error("Error loading capital city icons:", error);
  });
};
