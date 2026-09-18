/// How deep the backend's Pikafish search goes for a "Play vs Computer"
/// move - a coarse stand-in for engine strength until there's a reason to
/// build anything more elaborate (time controls, contempt, etc).
enum AiDifficulty { easy, medium, hard }

extension AiDifficultyX on AiDifficulty {
  /// Passed as `depth` to `POST /api/v1/engine/analyze`
  /// (`backend/src/routes/engine.routes.ts` caps this at `PIKAFISH_MAX_DEPTH`,
  /// 24 by default - all three values here are well under that).
  int get searchDepth => switch (this) {
        AiDifficulty.easy => 4,
        AiDifficulty.medium => 10,
        AiDifficulty.hard => 18,
      };

  String get label => switch (this) {
        AiDifficulty.easy => 'Easy',
        AiDifficulty.medium => 'Medium',
        AiDifficulty.hard => 'Hard',
      };
}
