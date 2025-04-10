
// C:\code\javascript\nestjs-hannibal-3\src\app.service.ts

import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  getHello(): string {
    return 'Hello World!';
  }
}
