/// The two players in Xiangqi. Red always moves first.
enum Side { red, black }

extension SideX on Side {
  Side get opponent => this == Side.red ? Side.black : Side.red;
}
