/**
 * Structural sanity check only - this is request validation, not a full
 * parser. It mirrors the conventions in the client's
 * `lib/domain/fen/fen_codec.dart` (10 ranks, 9 files, K/A/B/N/R/C/P piece
 * letters, uppercase Red / lowercase Black, 'w'/'b' side-to-move) so a FEN
 * that round-trips there is accepted here, but does not re-validate piece
 * counts or legality - Pikafish itself will reject a truly malformed
 * position via its own "info string CRITICAL ERROR" behavior.
 */
const RANK_PATTERN = /^[1-9krbnacpKRBNACP]+$/;
const VALID_PIECE_LETTERS = new Set('krbnacpKRBNACP'.split(''));

export function isPlausibleXiangqiFen(fen: string): boolean {
  const parts = fen.trim().split(/\s+/);
  if (parts.length < 2) return false;
  const [board, side] = parts;
  if (side !== 'w' && side !== 'b') return false;
  if (!board) return false;

  const ranks = board.split('/');
  if (ranks.length !== 10) return false;

  for (const rank of ranks) {
    if (!RANK_PATTERN.test(rank)) return false;
    let squares = 0;
    for (const ch of rank) {
      const digit = Number(ch);
      if (!Number.isNaN(digit)) {
        squares += digit;
      } else if (VALID_PIECE_LETTERS.has(ch)) {
        squares += 1;
      } else {
        return false;
      }
    }
    if (squares !== 9) return false;
  }

  return true;
}
