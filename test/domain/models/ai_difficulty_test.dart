import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/domain/models/ai_difficulty.dart';

void main() {
  group('AiDifficulty', () {
    test('search depth increases with difficulty', () {
      expect(AiDifficulty.easy.searchDepth, lessThan(AiDifficulty.medium.searchDepth));
      expect(AiDifficulty.medium.searchDepth, lessThan(AiDifficulty.hard.searchDepth));
    });

    test('every level has a non-empty label', () {
      for (final difficulty in AiDifficulty.values) {
        expect(difficulty.label, isNotEmpty);
      }
    });
  });
}
