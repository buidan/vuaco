import { afterEach, describe, expect, it, vi } from 'vitest';

import { GeminiVisionProvider } from '../../src/vision/geminiVisionProvider';
import { VisionAnalysisError } from '../../src/vision/visionProvider';

const START_FEN = 'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1';

function geminiResponse(jsonText: string) {
  return {
    ok: true,
    json: async () => ({ candidates: [{ content: { parts: [{ text: jsonText }] } }] }),
  };
}

describe('GeminiVisionProvider', () => {
  const originalFetch = globalThis.fetch;

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  it('sends the image as inline base64 data and the API key as a query param', async () => {
    let capturedUrl = '';
    let capturedBody: any;
    globalThis.fetch = vi.fn(async (url: string, init: any) => {
      capturedUrl = url;
      capturedBody = JSON.parse(init.body);
      return geminiResponse(JSON.stringify({ fen: START_FEN, confidence: 0.95 })) as any;
    }) as any;

    const provider = new GeminiVisionProvider('test-key', 'gemini-flash-latest');
    const result = await provider.analyzeBoardPhoto(Buffer.from('fake-image-bytes'), 'image/jpeg');

    expect(capturedUrl).toContain('models/gemini-flash-latest:generateContent');
    expect(capturedUrl).toContain('key=test-key');
    expect(capturedBody.contents[0].parts[1].inline_data.mime_type).toBe('image/jpeg');
    expect(capturedBody.contents[0].parts[1].inline_data.data).toBe(Buffer.from('fake-image-bytes').toString('base64'));
    expect(capturedBody.generationConfig.responseMimeType).toBe('application/json');
    expect(result).toEqual({ fen: START_FEN, confidence: 0.95 });
  });

  it('throws VisionAnalysisError when the HTTP call itself fails', async () => {
    globalThis.fetch = vi.fn(async () => {
      throw new Error('network down');
    }) as any;
    const provider = new GeminiVisionProvider('k', 'gemini-flash-latest');
    await expect(provider.analyzeBoardPhoto(Buffer.from('x'), 'image/jpeg')).rejects.toBeInstanceOf(
      VisionAnalysisError,
    );
  });

  it('throws VisionAnalysisError on a non-ok HTTP response', async () => {
    globalThis.fetch = vi.fn(async () => ({ ok: false, status: 503, text: async () => 'overloaded' })) as any;
    const provider = new GeminiVisionProvider('k', 'gemini-flash-latest');
    await expect(provider.analyzeBoardPhoto(Buffer.from('x'), 'image/jpeg')).rejects.toBeInstanceOf(
      VisionAnalysisError,
    );
  });

  it('throws VisionAnalysisError when the response has no candidates', async () => {
    globalThis.fetch = vi.fn(async () => ({ ok: true, json: async () => ({}) })) as any;
    const provider = new GeminiVisionProvider('k', 'gemini-flash-latest');
    await expect(provider.analyzeBoardPhoto(Buffer.from('x'), 'image/jpeg')).rejects.toBeInstanceOf(
      VisionAnalysisError,
    );
  });

  it('throws VisionAnalysisError when the model text is not valid JSON', async () => {
    globalThis.fetch = vi.fn(async () => geminiResponse('not json')) as any;
    const provider = new GeminiVisionProvider('k', 'gemini-flash-latest');
    await expect(provider.analyzeBoardPhoto(Buffer.from('x'), 'image/jpeg')).rejects.toBeInstanceOf(
      VisionAnalysisError,
    );
  });

  it('throws VisionAnalysisError when fen/confidence are missing from the parsed JSON', async () => {
    globalThis.fetch = vi.fn(async () => geminiResponse(JSON.stringify({ fen: START_FEN }))) as any;
    const provider = new GeminiVisionProvider('k', 'gemini-flash-latest');
    await expect(provider.analyzeBoardPhoto(Buffer.from('x'), 'image/jpeg')).rejects.toBeInstanceOf(
      VisionAnalysisError,
    );
  });
});
