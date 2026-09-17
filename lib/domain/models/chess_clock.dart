import 'side.dart';

/// Per-player timer configuration. Disabled by default for Phase 1's
/// Pass & Play mode; the presentation layer decides when/whether to tick it.
class ClockConfig {
  final bool enabled;
  final Duration initial;
  final Duration increment;

  const ClockConfig({
    this.enabled = false,
    this.initial = const Duration(minutes: 10),
    this.increment = Duration.zero,
  });
}

/// Pure countdown-clock data/logic - no timers or wall-clock access here.
/// The presentation layer is responsible for calling [consume] periodically
/// with elapsed wall-clock time.
class ChessClock {
  final ClockConfig config;
  Duration redRemaining;
  Duration blackRemaining;

  ChessClock(this.config)
      : redRemaining = config.initial,
        blackRemaining = config.initial;

  Duration remaining(Side side) => side == Side.red ? redRemaining : blackRemaining;

  void consume(Side side, Duration elapsed) {
    if (!config.enabled) return;
    final updated = remaining(side) - elapsed;
    final clamped = updated.isNegative ? Duration.zero : updated;
    if (side == Side.red) {
      redRemaining = clamped;
    } else {
      blackRemaining = clamped;
    }
  }

  void applyIncrement(Side side) {
    if (!config.enabled || config.increment == Duration.zero) return;
    if (side == Side.red) {
      redRemaining += config.increment;
    } else {
      blackRemaining += config.increment;
    }
  }

  bool isExpired(Side side) => config.enabled && remaining(side) <= Duration.zero;

  void reset() {
    redRemaining = config.initial;
    blackRemaining = config.initial;
  }
}
