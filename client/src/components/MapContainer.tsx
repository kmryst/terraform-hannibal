
// C:\code\javascript\graphql-react-hannibal-8\src\components\MapContainer.tsx

import { useEffect, useRef, useState } from "react";
import mapboxgl from "mapbox-gl";
import "mapbox-gl/dist/mapbox-gl.css";
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
  const mapRef = useRef<mapboxgl.Map | null>(null);
  const [progress, setProgress] = useState(0); // setProgess関数でprogressを更新する
  const { loading, error, data } = useQuery(GET_MAP_DATA);
  // loading: クエリが実行中の場合はtrueになり、完了するとfalseになります
  // error: クエリ実行中に発生したエラー情報が格納されます。エラーが発生していない場合はnullになります


  // デバッグ用: データ取得確認
  useEffect(() => {
    if (data) {
      console.log("Capital Cities Data:", data.capitalCities);
      console.log("Hannibal Route Data:", data.hannibalRoute);
      console.log("Point Route Data:", data.pointRoute);
    }
  }, [data]);

  // エラーハンドリング関数
  const handleError = (message: string, details?: Record<string, unknown>) => {
    // ... (既存のコード)
  };

  // マップ初期化処理
  useEffect(() => {
    if (!data || !mapContainerRef.current) return;

    try {
      mapRef.current = initializeMap(mapContainerRef.current);

      mapRef.current.on("style.load", () => {
        if (!mapRef.current) return;

        setTerrain(mapRef.current);
        setSnowEffect(mapRef.current);

        try {
          // GraphQLデータからレイヤーを追加
          addHannibalRouteLayers(mapRef.current, data.hannibalRoute, data.pointRoute);
          addCapitalCityLayers(mapRef.current, data.capitalCities);

          setupClickHandlers(mapRef.current);
          setupCursorHandlers(mapRef.current);

          console.log("Map layers added successfully.");
        } catch (e) {
          console.error("Error adding layers:", e);
          handleError(`Map layer error: ${e}`);
        }
      });

      return () => {
        mapRef.current?.remove();
      };
    } catch (e) {
      console.error("Map Initialization Failed:", e);
      handleError(`Map Initialization Failed: ${e}`);
    }
  }, [data]);

  return (
    <>
      <div ref={mapContainerRef} style={{ width: "100vw", height: "100vh" }} />
      
      {/* エラーログ表示 */}
      <div
        id="error-log"
        style={{
          position: "fixed",
          bottom: 0,
          left: 0,
          right: 0,
          backgroundColor: "rgba(255,255,255,0.95)",
          color: "red",
          zIndex: 9999,
          maxHeight: "30vh",
          overflowY: "auto",
          padding: "15px",
          borderTop: "1px solid #ddd",
          boxShadow: "0 -2px 10px rgba(0,0,0,0.05)",
          fontSize: "0.85em",
        }}
      >
        <div style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          marginBottom: "10px",
        }}>
          <h4 style={{ margin: 0 }}>システムログ</h4>
        </div>
      </div>
    </>
  );
};

export default MapContainer;
