import express, { Router } from 'express';

import { requireAuth } from '../auth/authMiddleware';
import { config } from '../config';
import { isPlausibleXiangqiFen } from '../utils/fen';
import { VisionAnalysisError, VisionProvider } from '../vision/visionProvider';

const ACCEPTED_MIME_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);

/**
 * `POST /api/v1/vision/scan` per docs/ARCHITECTURE.md section 5: body is
 * the raw image bytes (not multipart - one file, no other fields, so a
 * plain `Content-Type: image/jpeg|png|webp` request body is simplest for
 * both this route and the Flutter client) -> `{ fen, confidence }`.
 *
 * When [provider] is null (no `GEMINI_API_KEY` configured - see
 * `config/index.ts`), this always responds `501 not_implemented` instead,
 * so the endpoint has one stable contract whether or not Cloud Vision is
 * configured in a given environment.
 */
export function createVisionRouter(provider: VisionProvider | null): Router {
  const router = Router();

  router.post(
    '/vision/scan',
    requireAuth,
    express.raw({ type: () => true, limit: config.visionMaxImageBytes }),
    async (req, res, next) => {
      if (!provider) {
        res.status(501).json({
          error: 'not_implemented',
          message: 'Cloud Vision board scan is not configured on this server - paste a FEN or use the board editor instead.',
        });
        return;
      }

      const mimeType = req.headers['content-type'];
      if (typeof mimeType !== 'string' || !ACCEPTED_MIME_TYPES.has(mimeType)) {
        res.status(400).json({
          error: 'unsupported_media_type',
          message: `Content-Type must be one of: ${[...ACCEPTED_MIME_TYPES].join(', ')}`,
        });
        return;
      }

      if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
        res.status(400).json({ error: 'empty_body', message: 'Request body must be the raw image bytes.' });
        return;
      }

      try {
        const result = await provider.analyzeBoardPhoto(req.body, mimeType);
        if (!isPlausibleXiangqiFen(result.fen)) {
          throw new VisionAnalysisError(`Vision provider returned a malformed FEN: "${result.fen}"`);
        }
        res.json(result);
      } catch (err) {
        if (err instanceof VisionAnalysisError) {
          res.status(502).json({ error: 'vision_provider_error', message: err.message });
          return;
        }
        next(err);
      }
    },
  );

  return router;
}
