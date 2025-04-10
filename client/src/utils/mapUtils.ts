
// C:\code\javascript\nestjs-hannibal-1\client\src\utils\mapUtils.ts


import mapboxgl, { MapMouseEvent } from "mapbox-gl";

/**
 * クリックハンドラーを設定
 * @param map - Mapbox GL JS のマップインスタンス
 */
export const setupClickHandlers = (map: mapboxgl.Map): void => {
  map.on("click", "route-points", (e: MapMouseEvent) => {
    if (!e.features || e.features.length === 0) return;

    const feature = e.features[0];
    if (!feature.geometry || !("coordinates" in feature.geometry)) return;

    // coordinates が [number, number] 型であることを保証
    const coordinates = feature.geometry.coordinates;
    if (Array.isArray(coordinates) && coordinates.length === 2) {
      new mapboxgl.Popup()
        .setLngLat(coordinates as [number, number])
        .setHTML(feature.properties?.description || "説明なし")
        .addTo(map);
    } else {
      console.error("Invalid coordinates:", coordinates);
    }
  });
};

/**
 * マウスカーソルのハンドラーを設定
 * @param map - Mapbox GL JS のマップインスタンス
 */
export const setupCursorHandlers = (map: mapboxgl.Map): void => {
  // マウスが対象の上にある場合のカーソル変更
  map.on("mouseenter", "route-points", () => {
    map.getCanvas().style.cursor = "pointer"; // カーソルを指さす形に変更
  });

  // マウスが対象から離れた場合のカーソル変更
  map.on("mouseleave", "route-points", () => {
    map.getCanvas().style.cursor = ""; // デフォルトのカーソルに戻す
  });
};
