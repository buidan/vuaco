export interface BoardScanResult {
  /** Same convention as `src/xiangqi/fenCodec.ts` and the client's
   * `lib/domain/fen/fen_codec.dart` - K/A/B/N/R/C/P, uppercase Red. */
  fen: string;
  /** 0-1, the provider's own estimate of how confident it is in the read. */
  confidence: number;
}

export class VisionAnalysisError extends Error {}

/**
 * A photo -> FEN board reader. Kept as an interface (rather than calling a
 * vision API directly from the route) so the concrete provider is
 * swappable and fakeable in tests, the same pattern as `PikafishPool` and
 * the client's `EngineCoachRepository`.
 */
export interface VisionProvider {
  analyzeBoardPhoto(imageBytes: Buffer, mimeType: string): Promise<BoardScanResult>;
}
