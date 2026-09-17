import { Router } from 'express';

// TODO(Phase 5 follow-up): implement the real Cloud Vision pipeline once a
// provider/API key decision is made (see docs/ARCHITECTURE.md's Phase 5
// entry and RULES_ENGINE.md). Planned shape, so this stub's contract
// doesn't need to change when it's implemented:
//   - a `VisionProvider` interface (analyzeBoardPhoto(imageBytes) ->
//     { fen, confidence }) behind this route, so the concrete provider
//     (OpenAI GPT-4o vision, Gemini vision, ...) is swappable and fakeable
//     in tests the same way PikafishPool/EngineCoachRepository are.
//   - multipart image upload (e.g. multer), strip EXIF/location metadata
//     before sending anywhere external (docs/ARCHITECTURE.md section 7:
//     "must strip/avoid sending any user PII beyond the board photo itself").
//
// Until then this always responds 501 so the client has a stable contract
// to build the "scan a photo" entry point against without it silently
// doing nothing.

/**
 * `POST /api/v1/vision/scan` per docs/ARCHITECTURE.md section 5 - not
 * implemented yet (Phase 5 shipped manual FEN paste + the board-correction
 * UI only; see the TODO above for what's planned here).
 */
export function createVisionRouter(): Router {
  const router = Router();

  router.post('/vision/scan', (_req, res) => {
    res.status(501).json({
      error: 'not_implemented',
      message: 'Cloud Vision board scan is not implemented yet - paste a FEN or use the board editor instead.',
    });
  });

  return router;
}
