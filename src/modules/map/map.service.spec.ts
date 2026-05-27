import { capitalCities } from '../../geojson_data/capitalCities';
import { MapService } from './map.service';

describe('MapService', () => {
  let service: MapService;

  beforeEach(() => {
    service = new MapService();
  });

  it('returns capital city GeoJSON data', () => {
    expect(service.getCapitalCities()).toBe(capitalCities);
  });
});
