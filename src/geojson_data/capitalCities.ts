

// C:\code\javascript\nestjs-hannibal-1\src\geojson_data\capitalCities.ts

export const capitalCities = {
  type: "FeatureCollection",
  features: [
    {
      type: "Feature",
      geometry: {
        type: "Point",
        coordinates: [12.4964, 41.9028],
      },
      properties: {
        name: "Roma",
        description: "古代ローマ帝国の首都",
        empire: "Roman",
      },
    },
    {
      type: "Feature",
      geometry: {
        type: "Point",
        coordinates: [10.3233, 36.8529],
      },
      properties: {
        name: "Carthage",
        description: "カルタゴ帝国の首都",
        empire: "Carthaginian",
      },
    },
  ],
};

