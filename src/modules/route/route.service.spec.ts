import { Repository } from 'typeorm';
import { Route } from '../../entities';
import { hannibalRoute } from '../../geojson_data/hannibalRoute';
import { pointRoute } from '../../geojson_data/pointRoute';
import { RouteService } from './route.service';

type RouteRepositoryMock = {
  find: jest.Mock;
  findOne: jest.Mock;
  create: jest.Mock;
  save: jest.Mock;
  update: jest.Mock;
  delete: jest.Mock;
  count: jest.Mock;
};

const createRoute = (overrides: Partial<Route> = {}): Route => ({
  id: 1,
  name: 'Test route',
  description: 'A route used by unit tests',
  coordinates: [
    [10, 20],
    [30, 40],
  ],
  color: '#ff0000',
  createdAt: new Date('2026-01-01T00:00:00.000Z'),
  updatedAt: new Date('2026-01-02T00:00:00.000Z'),
  ...overrides,
});

describe('RouteService', () => {
  let service: RouteService;
  let routeRepository: RouteRepositoryMock;

  beforeEach(() => {
    routeRepository = {
      find: jest.fn(),
      findOne: jest.fn(),
      create: jest.fn(),
      save: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
      count: jest.fn(),
    };

    service = new RouteService(routeRepository as unknown as Repository<Route>);
  });

  describe('findAll', () => {
    it('returns all routes from the repository', async () => {
      const routes = [createRoute(), createRoute({ id: 2, name: 'Second' })];
      routeRepository.find.mockResolvedValue(routes);

      await expect(service.findAll()).resolves.toEqual(routes);
      expect(routeRepository.find).toHaveBeenCalledTimes(1);
    });
  });

  describe('findOne', () => {
    it('returns the route that matches the given id', async () => {
      const route = createRoute({ id: 42 });
      routeRepository.findOne.mockResolvedValue(route);

      await expect(service.findOne(42)).resolves.toEqual(route);
      expect(routeRepository.findOne).toHaveBeenCalledWith({
        where: { id: 42 },
      });
    });

    it('returns null when the repository has no matching route', async () => {
      routeRepository.findOne.mockResolvedValue(null);

      await expect(service.findOne(404)).resolves.toBeNull();
    });
  });

  describe('create', () => {
    it('creates and saves a route', async () => {
      const routeData: Partial<Route> = {
        name: 'Created route',
        description: 'Created by a test',
        coordinates: [[1, 2]],
        color: '#00ff00',
      };
      const createdRoute = createRoute(routeData);
      routeRepository.create.mockReturnValue(createdRoute);
      routeRepository.save.mockResolvedValue(createdRoute);

      await expect(service.create(routeData)).resolves.toEqual(createdRoute);
      expect(routeRepository.create).toHaveBeenCalledWith(routeData);
      expect(routeRepository.save).toHaveBeenCalledWith(createdRoute);
    });
  });

  describe('update', () => {
    it('updates a route and returns the refreshed entity', async () => {
      const updatedRoute = createRoute({
        id: 7,
        description: 'Updated description',
      });
      routeRepository.update.mockResolvedValue({ affected: 1 });
      routeRepository.findOne.mockResolvedValue(updatedRoute);

      await expect(
        service.update(7, { description: 'Updated description' }),
      ).resolves.toEqual(updatedRoute);
      expect(routeRepository.update).toHaveBeenCalledWith(7, {
        description: 'Updated description',
      });
      expect(routeRepository.findOne).toHaveBeenCalledWith({
        where: { id: 7 },
      });
    });
  });

  describe('remove', () => {
    it('deletes a route by id', async () => {
      routeRepository.delete.mockResolvedValue({ affected: 1 });

      await expect(service.remove(3)).resolves.toBeUndefined();
      expect(routeRepository.delete).toHaveBeenCalledWith(3);
    });
  });

  describe('seedInitialData', () => {
    it('saves the Hannibal route when the repository is empty', async () => {
      routeRepository.count.mockResolvedValue(0);
      routeRepository.save.mockResolvedValue(createRoute());

      await service.seedInitialData();

      expect(routeRepository.save).toHaveBeenCalledWith(
        expect.objectContaining({
          name: 'ハンニバルルート',
          description: 'ハンニバルがアルプスを越えた歴史的ルート',
          coordinates: hannibalRoute.features[0].geometry.coordinates,
          color: '#ff0000',
        }),
      );
    });

    it('does not seed data when routes already exist', async () => {
      routeRepository.count.mockResolvedValue(1);

      await service.seedInitialData();

      expect(routeRepository.save).not.toHaveBeenCalled();
    });
  });

  describe('legacy GeoJSON accessors', () => {
    it('returns Hannibal route GeoJSON data', () => {
      expect(service.getHannibalRoute()).toMatchObject({
        type: hannibalRoute.type,
        features: [
          expect.objectContaining({
            geometry: expect.objectContaining({
              type: 'LineString',
              coordinates: hannibalRoute.features[0].geometry.coordinates,
            }),
          }),
        ],
      });
    });

    it('returns point route GeoJSON data', () => {
      expect(service.getPointRoute()).toBe(pointRoute);
    });
  });
});
