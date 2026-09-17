import { BoardScanResult, VisionProvider } from './visionProvider';

/** Deterministic stand-in for tests - never calls a real API. */
export class FakeVisionProvider implements VisionProvider {
  constructor(private readonly result: BoardScanResult) {}

  async analyzeBoardPhoto(): Promise<BoardScanResult> {
    return this.result;
  }
}
