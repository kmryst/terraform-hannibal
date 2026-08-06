// C:\code\javascript\nestjs-hannibal-3\client\src\components\MapContainer.tsx

import { useEffect, useRef, useState } from "react";
import { gql } from "@apollo/client";
// Apollo Client 4 で React 向けの export は '@apollo/client/react' へ移動した
import { useQuery } from "@apollo/client/react";
import {
  initializeMap,
  setTerrain,
  setSnowEffect,
} from "../services/mapSetup";
import {
  addHannibalRouteLayers,
  addCapitalCityLayers,
} from "../services/mapLayers";
import { setupClickHandlers, setupCursorHandlers } from "../utils/mapUtils";
import type * as GeoJSON from "geojson";

// Apollo Client 4 の useQuery は TData の既定値が any ではなくなったため、
// GET_MAP_DATA の戻り値型を明示する。実行時の挙動は 3 系と同じ。
type GetMapDataQuery = {
  capitalCities: GeoJSON.FeatureCollection<
    GeoJSON.Point,
    { empire: string; name: string }
  >;
  hannibalRoute: GeoJSON.FeatureCollection<GeoJSON.LineString>;
  pointRoute: GeoJSON.FeatureCollection<GeoJSON.Point>;
};

// GraphQLクエリ
const GET_MAP_DATA = gql`
  query GetMapData {
    capitalCities {
      type
      features {
        type
        geometry {
          type
          coordinates
        }
        properties {
          name
          description
          empire
        }
      }
    }
    hannibalRoute {
      type
      features {
        type
        geometry {
          type
          coordinates
        }
        properties {
          description
        }
      }
    }
    pointRoute {
      type
      features {
        type
        geometry {
          type
          coordinates
        }
        properties {
          description
        }
      }
    }
  }
`;

const MapContainer: React.FC = () => {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<any>(null);
  const [isMapboxLoading, setIsMapboxLoading] = useState(true);
  const { loading, error, data } = useQuery<GetMapDataQuery>(GET_MAP_DATA);

  // Mapboxの動的インポート
  // 初期バンドルサイズを削減するため、Mapboxを動的に読み込む
  useEffect(() => {
    const loadMapbox = async () => {
      try {
        // MapboxのライブラリとCSSを動的にインポート
        const mapboxgl = await import('mapbox-gl');
        await import('mapbox-gl/dist/mapbox-gl.css');
        mapRef.current = mapboxgl.default ?? mapboxgl;
        setIsMapboxLoading(false);
      } catch (error) {
        console.error('Error loading Mapbox:', error);
      }
    };

    loadMapbox();
  }, []);

  // デバッグ用: データ取得確認
  useEffect(() => {
    if (data) {
      console.log("Capital Cities Data:", data.capitalCities);
      console.log("Hannibal Route Data:", data.hannibalRoute);
      console.log("Point Route Data:", data.pointRoute);
    }
  }, [data]);



  // マップ初期化処理
  useEffect(() => {
    if (!data || !mapContainerRef.current || isMapboxLoading || !mapRef.current) return;

    try {
      const map = initializeMap(mapContainerRef.current, mapRef.current);

      map.on("style.load", () => {
        if (!map) return;

        setTerrain(map);
        setSnowEffect(map);

        try {
          addHannibalRouteLayers(map, data.hannibalRoute, data.pointRoute);
          addCapitalCityLayers(map, data.capitalCities);

          setupClickHandlers(map);
          setupCursorHandlers(map);

          console.log("Map layers added successfully.");
        } catch (e) {
          console.error("Error adding layers:", e);
        }
      });

      return () => {
        map?.remove();
      };
    } catch (e) {
      console.error("Map Initialization Failed:", e);
    }
  }, [data, isMapboxLoading]);

  if (isMapboxLoading) {
    return <div>Loading Mapbox...</div>;
  }

  return (
    <>
      <div ref={mapContainerRef} style={{ width: "100vw", height: "100vh" }} />

      {loading && (
        <div style={{ position: "fixed", top: 0, left: 0, color: "blue", background: "white", zIndex: 10000, padding: "4px 8px" }}>
          Loading...
        </div>
      )}
      {error && (
        <div style={{ position: "fixed", top: 30, left: 0, color: "red", background: "white", zIndex: 10000, padding: "4px 8px" }}>
          Error: {error.message}
        </div>
      )}


    </>
  );
};

export default MapContainer;
