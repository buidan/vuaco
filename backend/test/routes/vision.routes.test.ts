import express from 'express';
import request from 'supertest';
import { describe, expect, it } from 'vitest';

import { createVisionRouter } from '../../src/routes/vision.routes';

describe('POST /api/v1/vision/scan', () => {
  it('responds 501 not_implemented (Cloud Vision is deferred - see the TODO in vision.routes.ts)', async () => {
    const app = express();
    app.use('/api/v1', createVisionRouter());
    const res = await request(app).post('/api/v1/vision/scan').send({});
    expect(res.status).toBe(501);
    expect(res.body.error).toBe('not_implemented');
  });
});
