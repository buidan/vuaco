import { BoardScanResult, VisionAnalysisError, VisionProvider } from './visionProvider';

const PROMPT = `You are reading a photograph of a Xiangqi (Chinese Chess) board.

Identify every piece on the board and produce a FEN string using this exact convention:
- 10 ranks separated by "/", listed from Black's back rank (top of the board as photographed) to Red's back rank (bottom).
- Each rank has exactly 9 squares: a run of empty squares is written as a single digit (1-9), pieces are written as letters.
- Piece letters: K = General, A = Advisor, B = Elephant, N = Horse, R = Chariot, C = Cannon, P = Soldier.
- Uppercase letters for Red pieces (the pieces with red/crimson carved characters), lowercase for Black pieces (dark/black carved characters).
- You cannot tell whose turn it is from a photo alone - always report the side-to-move field as "w" (Red).

Respond only with the requested JSON: "fen" must be the full FEN string in the form "<board> w - - 0 1", and "confidence" must be your own honest estimate (0 to 1) of how certain you are that every square was read correctly - lower it for blur, glare, occlusion, or an unclear photo angle.`;

interface GeminiGenerateContentResponse {
  candidates?: Array<{
    content?: {
      parts?: Array<{ text?: string }>;
    };
  }>;
}

/**
 * Calls Google's Gemini API (multimodal `generateContent`, requesting
 * structured JSON output via `responseSchema` so parsing the reply doesn't
 * involve scraping free-form text) to read a Xiangqi board photo into a
 * FEN. See docs/ARCHITECTURE.md section 7: this sends the photo (and
 * nothing else - no location, no device info) to an external API, which is
 * the one exception to "never call a third party with user data" this
 * codebase makes, and only for this one endpoint.
 */
export class GeminiVisionProvider implements VisionProvider {
  constructor(
    private readonly apiKey: string,
    private readonly model: string,
  ) {}

  async analyzeBoardPhoto(imageBytes: Buffer, mimeType: string): Promise<BoardScanResult> {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent?key=${this.apiKey}`;

    const body = {
      contents: [
        {
          parts: [{ text: PROMPT }, { inline_data: { mime_type: mimeType, data: imageBytes.toString('base64') } }],
        },
      ],
      generationConfig: {
        responseMimeType: 'application/json',
        responseSchema: {
          type: 'OBJECT',
          properties: {
            fen: { type: 'STRING' },
            confidence: { type: 'NUMBER' },
          },
          required: ['fen', 'confidence'],
        },
      },
    };

    let response: Response;
    try {
      response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
    } catch (err) {
      throw new VisionAnalysisError(`Could not reach the vision provider: ${err}`);
    }

    if (!response.ok) {
      const text = await response.text().catch(() => '');
      throw new VisionAnalysisError(`Vision provider returned HTTP ${response.status}: ${text}`);
    }

    let parsed: GeminiGenerateContentResponse;
    try {
      parsed = (await response.json()) as GeminiGenerateContentResponse;
    } catch (err) {
      throw new VisionAnalysisError(`Vision provider returned malformed JSON: ${err}`);
    }

    const text = parsed.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) {
      throw new VisionAnalysisError('Vision provider response had no content');
    }

    let result: Partial<BoardScanResult>;
    try {
      result = JSON.parse(text) as Partial<BoardScanResult>;
    } catch (err) {
      throw new VisionAnalysisError(`Vision provider content was not valid JSON: ${err}`);
    }

    if (typeof result.fen !== 'string' || typeof result.confidence !== 'number') {
      throw new VisionAnalysisError('Vision provider response is missing fen/confidence');
    }

    return { fen: result.fen, confidence: result.confidence };
  }
}
