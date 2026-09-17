import { describe, expect, it } from 'vitest';

import { isPlausibleXiangqiFen } from '../../src/utils/fen';

describe('isPlausibleXiangqiFen', () => {
  it('accepts the standard starting position (matches the Dart FenCodec output)', () => {
    expect(isPlausibleXiangqiFen('rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1')).toBe(
      true,
    );
  });

  it('accepts Black to move', () => {
    expect(isPlausibleXiangqiFen('rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR b - - 0 1')).toBe(
      true,
    );
  });

  it('accepts a sparse board with just the two generals', () => {
    expect(isPlausibleXiangqiFen('4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1')).toBe(true);
  });

  it('rejects a side-to-move letter other than w/b', () => {
    expect(isPlausibleXiangqiFen('4k4/9/9/9/9/9/9/9/9/4K4 x - - 0 1')).toBe(false);
  });

  it('rejects a board with fewer than 10 ranks', () => {
    expect(isPlausibleXiangqiFen('9/9/9 w - - 0 1')).toBe(false);
  });

  it('rejects a rank whose square count does not sum to 9', () => {
    expect(isPlausibleXiangqiFen('4k3/9/9/9/9/9/9/9/9/4K4 w - - 0 1')).toBe(false);
  });

  it('rejects an unknown piece letter', () => {
    expect(isPlausibleXiangqiFen('4z4/9/9/9/9/9/9/9/9/4K4 w - - 0 1')).toBe(false);
  });

  it('rejects a string with no side-to-move field at all', () => {
    expect(isPlausibleXiangqiFen('4k4/9/9/9/9/9/9/9/9/4K4')).toBe(false);
  });
});
