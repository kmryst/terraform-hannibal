

// C:\code\javascript\nestjs-hannibal-3\client\src\services\mapSetup.ts

import mapboxgl, { PropertyValueSpecification } from "mapbox-gl";


/* 
  「ズームレベルに応じて要素を段階的に表示する」という意味
  ズームレベルは 0~22
  なにかの設定の値を制御する
  */
// export const zoomBasedReveal = (maxValue: number) => [
// 	"interpolate", // 補間を行うことを示す
// 	["linear"], // 線形補間方式を使用
// 	["zoom"], // ズームレベルを入力値として使用
// 	5,
// 	0, // ズームレベル5で値は0
// 	8,
// 	maxValue, // ズームレベル8で値はmaxValue
// ];


const zoomBasedReveal = (maxValue: number): PropertyValueSpecification<number> => {
    return [
        "interpolate",
        ["linear"],
        ["zoom"],
        5,
        0,
        8,
        maxValue
    ];
};



// マップの初期化
export const initializeMap = (container: HTMLDivElement) => {
	mapboxgl.accessToken =
		"pk.eyJ1IjoiZ2F0c2J5a2VuamkiLCJhIjoiY202azF4Y2trMDcxcDJqcXFlZXh0a212NSJ9.vxT12MITCjAxQloXvl8L_g";

	const map = new mapboxgl.Map({
		container: container,
		style: "mapbox://styles/mapbox/satellite-v9",
		// style: 'mapbox://styles/mapbox/streets-v11',

		// center: [6.8640, 45.8326],
		center: [13.0, 57.0],
		zoom: 2.5,
		pitch: 60,
		bearing: 0,
		antialias: true,
	});

	// ナビゲーションコントロールの追加
	map.addControl(
		new mapboxgl.NavigationControl({
			visualizePitch: true, // pitchに合わせてコンパスも傾く
			showZoom: true,　// ズームボタン表示
			showCompass: true, // コンパス表示
		}),
	);

	return map;
};

// 3Dテレインの設定
export const setTerrain = (map: mapboxgl.Map) => { // TypeScript type annotation
	map.addSource("terrain-source", {
		type: "raster-dem",
		url: "mapbox://mapbox.terrain-rgb",
		tileSize: 512,
	});

	map.setTerrain({
		source: "terrain-source",
		exaggeration: 3,
	});
};

// 雪の効果を追加
export const setSnowEffect = (map: mapboxgl.Map) => {
	map.setSnow({
		density: zoomBasedReveal(0.85), // 密度　1までは取りうる？
		intensity: 1.0, // 強度　1までは取りうる？
		"center-thinning": 0.1, // 中心の薄さ
		direction: [0, 50], // 雪の落下方向
		opacity: 1.0, // 不透明度を1.0（完全に不透明）に設定
		color: "#ffffff",
		"flake-size": 0.71, // 雪のサイズ
		vignette: 1, // vignette: zoomBasedReveal(0.3), // 周辺部を暗くして雰囲気を出すこと ヴィネット、ヴィニェット
		// "vignette-color": "#ffffff", // 白
		"vignette-color": "#000000", // 黒
	});
};

