import express from 'express';
import request from 'supertest';
import { describe, expect, it } from 'vitest';

import { signAuthToken } from '../../src/auth/jwt';
import { errorHandler } from '../../src/middleware/errorHandler';
import { createVisionRouter } from '../../src/routes/vision.routes';
import { FakeVisionProvider } from '../../src/vision/fakeVisionProvider';
import { VisionAnalysisError, VisionProvider } from '../../src/vision/visionProvider';

const START_FEN = 'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1';
const token = signAuthToken({ sub: 'user-1', username: 'Dan' });

function buildApp(provider: VisionProvider | null) {
  const app = express();
  app.use('/api/v1', createVisionRouter(provider));
  app.use(errorHandler);
  return app;
}

describe('POST /api/v1/vision/scan', () => {
  it('responds 501 not_implemented when no provider is configured', async () => {
    const res = await request(buildApp(null))
      .post('/api/v1/vision/scan')
      .set('Authorization', `Bearer ${token}`)
      .set('Content-Type', 'image/jpeg')
      .send(Buffer.from('fake-jpeg-bytes'));
    expect(res.status).toBe(501);
    expect(res.body.error).toBe('not_implemented');
  });

  it('requires auth even when a provider is configured', async () => {
    const app = buildApp(new FakeVisionProvider({ fen: START_FEN, confidence: 0.9 }));
    const res = await request(app).post('/api/v1/vision/scan').set('Content-Type', 'image/jpeg').send(Buffer.from('x'));
    expect(res.status).toBe(401);
  });

  it('returns the provider\'s fen/confidence for a well-formed image upload', async () => {
    const app = buildApp(new FakeVisionProvider({ fen: START_FEN, confidence: 0.87 }));
    const res = await request(app)
      .post('/api/v1/vision/scan')
      .set('Authorization', `Bearer ${token}`)
      .set('Content-Type', 'image/jpeg')
      .send(Buffer.from('fake-jpeg-bytes'));
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ fen: START_FEN, confidence: 0.87 });
  });

  it('rejects an unsupported content type', async () => {
    const app = buildApp(new FakeVisionProvider({ fen: START_FEN, confidence: 0.9 }));
    const res = await request(app)
      .post('/api/v1/vision/scan')
      .set('Authorization', `Bearer ${token}`)
      .set('Content-Type', 'text/plain')
      .send('not an image');
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('unsupported_media_type');
  });

  it('rejects an empty body', async () => {
    const app = buildApp(new FakeVisionProvider({ fen: START_FEN, confidence: 0.9 }));
    const res = await request(app)
      .post('/api/v1/vision/scan')
      .set('Authorization', `Bearer ${token}`)
      .set('Content-Type', 'image/jpeg')
      .send(Buffer.alloc(0));
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('empty_body');
  });

  it('maps a provider failure to 502', async () => {
    const failing: VisionProvider = {
      analyzeBoardPhoto: async () => {
        throw new VisionAnalysisError('upstream exploded');
      },
    };
    const res = await request(buildApp(failing))
      .post('/api/v1/vision/scan')
      .set('Authorization', `Bearer ${token}`)
      .set('Content-Type', 'image/jpeg')
      .send(Buffer.from('x'));
    expect(res.status).toBe(502);
    expect(res.body.error).toBe('vision_provider_error');
  });

  it('treats a structurally malformed fen from the provider as a provider error', async () => {
    const app = buildApp(new FakeVisionProvider({ fen: 'not-a-fen', confidence: 0.5 }));
    const res = await request(app)
      .post('/api/v1/vision/scan')
      .set('Authorization', `Bearer ${token}`)
      .set('Content-Type', 'image/jpeg')
      .send(Buffer.from('x'));
    expect(res.status).toBe(502);
    expect(res.body.error).toBe('vision_provider_error');
  });
});
