import { render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import MapContainer from './MapContainer';

const mocks = vi.hoisted(() => ({
  addCapitalCityLayers: vi.fn(),
  addHannibalRouteLayers: vi.fn(),
  initializeMap: vi.fn(),
  setSnowEffect: vi.fn(),
  setTerrain: vi.fn(),
  setupClickHandlers: vi.fn(),
  setupCursorHandlers: vi.fn(),
  useQuery: vi.fn(),
}));

vi.mock('@apollo/client', () => ({
  gql: (strings: TemplateStringsArray) => strings.join(''),
  useQuery: mocks.useQuery,
}));

vi.mock('mapbox-gl', () => ({
  default: {},
}));

vi.mock('../services/mapSetup', () => ({
  initializeMap: mocks.initializeMap,
  setSnowEffect: mocks.setSnowEffect,
  setTerrain: mocks.setTerrain,
}));

vi.mock('../services/mapLayers', () => ({
  addCapitalCityLayers: mocks.addCapitalCityLayers,
  addHannibalRouteLayers: mocks.addHannibalRouteLayers,
}));

vi.mock('../utils/mapUtils', () => ({
  setupClickHandlers: mocks.setupClickHandlers,
  setupCursorHandlers: mocks.setupCursorHandlers,
}));

type MapMock = {
  on: ReturnType<typeof vi.fn>;
  remove: ReturnType<typeof vi.fn>;
};

const createMapMock = (): MapMock => {
  const map: MapMock = {
    on: vi.fn((event: string, callback: () => void) => {
      if (event === 'style.load') {
        callback();
      }

      return map;
    }),
    remove: vi.fn(),
  };

  return map;
};

const mapData = {
  capitalCities: {
    type: 'FeatureCollection',
    features: [],
  },
  hannibalRoute: {
    type: 'FeatureCollection',
    features: [
      {
        type: 'Feature',
        geometry: {
          type: 'LineString',
          coordinates: [
            [10, 20],
            [30, 40],
          ],
        },
        properties: {},
      },
    ],
  },
  pointRoute: {
    type: 'FeatureCollection',
    features: [],
  },
};

describe('MapContainer', () => {
  let consoleLogSpy: ReturnType<typeof vi.spyOn>;
  let consoleErrorSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    vi.clearAllMocks();
    consoleLogSpy = vi.spyOn(console, 'log').mockImplementation(() => {});
    consoleErrorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
    mocks.useQuery.mockReturnValue({
      loading: false,
      error: undefined,
      data: undefined,
    });
    mocks.initializeMap.mockReturnValue(createMapMock());
  });

  afterEach(() => {
    consoleLogSpy.mockRestore();
    consoleErrorSpy.mockRestore();
  });

  it('shows the Mapbox loading state before the map module is ready', () => {
    render(<MapContainer />);

    expect(screen.getByText('Loading Mapbox...')).toBeInTheDocument();
  });

  it('shows the Apollo loading overlay after Mapbox is loaded', async () => {
    mocks.useQuery.mockReturnValue({
      loading: true,
      error: undefined,
      data: undefined,
    });

    render(<MapContainer />);

    expect(await screen.findByText('Loading...')).toBeInTheDocument();
  });

  it('shows the Apollo error overlay after Mapbox is loaded', async () => {
    mocks.useQuery.mockReturnValue({
      loading: false,
      error: new Error('GraphQL failed'),
      data: undefined,
    });

    render(<MapContainer />);

    expect(await screen.findByText('Error: GraphQL failed')).toBeInTheDocument();
  });

  it('initializes map layers and handlers when map data is ready', async () => {
    const map = createMapMock();
    mocks.useQuery.mockReturnValue({
      loading: false,
      error: undefined,
      data: mapData,
    });
    mocks.initializeMap.mockReturnValue(map);

    render(<MapContainer />);

    await waitFor(() => {
      expect(mocks.initializeMap).toHaveBeenCalledTimes(1);
    });
    expect(mocks.setTerrain).toHaveBeenCalledWith(map);
    expect(mocks.setSnowEffect).toHaveBeenCalledWith(map);
    expect(mocks.addHannibalRouteLayers).toHaveBeenCalledWith(
      map,
      mapData.hannibalRoute,
      mapData.pointRoute,
    );
    expect(mocks.addCapitalCityLayers).toHaveBeenCalledWith(
      map,
      mapData.capitalCities,
    );
    expect(mocks.setupClickHandlers).toHaveBeenCalledWith(map);
    expect(mocks.setupCursorHandlers).toHaveBeenCalledWith(map);
  });
});
