
// C:\code\javascript\nestjs-hannibal-3\src\app.controller.spec.ts

import { Test, TestingModule } from '@nestjs/testing';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Route } from './entities';

describe('AppController', () => {
  let appController: AppController;

  beforeEach(async () => {
    const mockRepository = {
      manager: {
        connection: {
          query: jest.fn().mockResolvedValue([{ result: 1 }])
        }
      }
    };

    const app: TestingModule = await Test.createTestingModule({
      controllers: [AppController],
      providers: [
        AppService,
        {
          provide: getRepositoryToken(Route),
          useValue: mockRepository,
        },
      ],
    }).compile();

    appController = app.get<AppController>(AppController);
  });

  describe('root', () => {
    it('should return "Hello World!"', () => {
      expect(appController.getHello()).toBe('Hello World!');
    });
  });

  describe('health checks', () => {
    it('should return health status', async () => {
      const result = await appController.getHealth();
      expect(result).toHaveProperty('status');
      expect(result).toHaveProperty('timestamp');
      expect(result).toHaveProperty('checks');
    });

    it('should return readiness status', async () => {
      const result = await appController.getReadiness();
      expect(result).toHaveProperty('status');
      expect(result).toHaveProperty('timestamp');
    });

    it('should return liveness status', async () => {
      const result = await appController.getLiveness();
      expect(result).toHaveProperty('status', 'alive');
      expect(result).toHaveProperty('uptime');
    });
  });
});
