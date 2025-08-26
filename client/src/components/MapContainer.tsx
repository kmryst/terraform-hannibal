// C:\code\javascript\nestjs-hannibal-3\client\src\components\MapContainer.tsx

import { useEffect, useRef, useState } from "react";
import { useQuery, gql } from "@apollo/client";
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
  const [progress, setProgress] = useState(0);
  const [isMapboxLoading, setIsMapboxLoading] = useState(true);
  const { loading, error, data } = useQuery(GET_MAP_DATA);

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
