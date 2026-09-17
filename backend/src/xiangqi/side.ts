/** The two players in Xiangqi. Red always moves first. Ported 1:1 from the
 * client's `lib/domain/models/side.dart` - see RULES_ENGINE.md there for
 * the orientation this whole module follows. */
export type Side = 'red' | 'black';

export function opponent(side: Side): Side {
  return side === 'red' ? 'black' : 'red';
}
