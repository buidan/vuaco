import { Side } from '../xiangqi/side';

export interface TimeControl {
  enabled: boolean;
  initialMs: number;
  incrementMs: number;
}

export const UNTIMED: TimeControl = { enabled: false, initialMs: 0, incrementMs: 0 };

export function timeControlFromRequest(minutes?: number, incrementSeconds?: number): TimeControl {
  if (!minutes || minutes <= 0) return UNTIMED;
  return {
    enabled: true,
    initialMs: Math.round(minutes * 60_000),
    incrementMs: Math.round((incrementSeconds ?? 0) * 1000),
  };
}

/** Server-authoritative wall-clock countdown for one room. Mutates in
 * place (unlike the client's pure `ChessClock`) since this lives inside a
 * single long-lived `RoomRuntime`, not a value passed around a UI tree. */
export class RoomClock {
  redRemainingMs: number;
  blackRemainingMs: number;
  private lastTickAt: number;

  constructor(private readonly control: TimeControl) {
    this.redRemainingMs = control.initialMs;
    this.blackRemainingMs = control.initialMs;
    this.lastTickAt = Date.now();
  }

  get enabled(): boolean {
    return this.control.enabled;
  }

  remaining(side: Side): number {
    return side === 'red' ? this.redRemainingMs : this.blackRemainingMs;
  }

  private setRemaining(side: Side, valueMs: number): void {
    const clamped = Math.max(0, valueMs);
    if (side === 'red') this.redRemainingMs = clamped;
    else this.blackRemainingMs = clamped;
  }

  /** Deducts elapsed wall-clock time from `side`'s remaining time, without
   * resetting the tick reference - call this to check for a flag-fall
   * before deciding whether a move/tick is even still valid. */
  consumeElapsed(side: Side): void {
    if (!this.control.enabled) return;
    const now = Date.now();
    const elapsed = now - this.lastTickAt;
    this.setRemaining(side, this.remaining(side) - elapsed);
    this.lastTickAt = now;
  }

  /** Call once a move by `side` has been accepted: applies their
   * increment and starts the opponent's clock ticking from now. */
  applyIncrementAndSwitch(side: Side): void {
    if (!this.control.enabled) return;
    this.setRemaining(side, this.remaining(side) + this.control.incrementMs);
    this.lastTickAt = Date.now();
  }

  isExpired(side: Side): boolean {
    return this.control.enabled && this.remaining(side) <= 0;
  }
}
