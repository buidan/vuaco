import { ChildProcessWithoutNullStreams, spawn } from 'node:child_process';
import { createInterface, Interface } from 'node:readline';

import { AnalysisLine, AnalysisResult, AnalyzeOptions } from './types';
import { parseBestMoveLine, parseInfoLine } from './uciInfoParser';

export interface PikafishProcessOptions {
  binPath: string;
  cwd: string;
  nnuePath: string;
  threads: number;
  hashMb: number;
  /** Extra args passed to `binPath`. Only used by tests, to spawn a fixture
   * script via `node <script>` instead of the real Pikafish binary. */
  args?: string[];
}

/**
 * Owns exactly one Pikafish OS process, spoken to over its stdin/stdout via
 * the UCI text protocol. This is the GPL isolation boundary: Pikafish's
 * GPL-3.0 binary is invoked as a separate, unmodified executable - never
 * linked into this TypeScript process - so nothing here becomes a
 * derivative work under GPL. See backend/README.md.
 */
export class PikafishProcess {
  readonly id: number;
  private readonly options: PikafishProcessOptions;
  private child: ChildProcessWithoutNullStreams | null = null;
  private rl: Interface | null = null;
  private ready = false;
  private lastMultiPv = 1;

  constructor(id: number, options: PikafishProcessOptions) {
    this.id = id;
    this.options = options;
  }

  async start(): Promise<void> {
    const child = spawn(this.options.binPath, this.options.args ?? [], { cwd: this.options.cwd });
    this.child = child;
    this.rl = createInterface({ input: child.stdout });

    child.on('error', (err) => {
      throw new Error(`Pikafish process #${this.id} failed to start: ${err.message}`);
    });

    await this.handshake();
  }

  private write(command: string): void {
    if (!this.child) throw new Error(`Pikafish process #${this.id} is not started`);
    this.child.stdin.write(`${command}\n`);
  }

  /** Resolves once `predicate` returns true for a received line. Every line
   * seen while waiting is also forwarded to `onLine`, if given. */
  private waitFor(predicate: (line: string) => boolean, onLine?: (line: string) => void): Promise<string> {
    return new Promise((resolve) => {
      const listener = (line: string) => {
        onLine?.(line);
        if (predicate(line)) {
          this.rl?.off('line', listener);
          resolve(line);
        }
      };
      this.rl?.on('line', listener);
    });
  }

  private async handshake(): Promise<void> {
    this.write('uci');
    await this.waitFor((line) => line.trim() === 'uciok');

    this.write(`setoption name Threads value ${this.options.threads}`);
    this.write(`setoption name Hash value ${this.options.hashMb}`);
    this.write(`setoption name EvalFile value ${this.options.nnuePath}`);

    this.write('isready');
    await this.waitFor((line) => line.trim() === 'readyok');
    this.ready = true;
  }

  get isReady(): boolean {
    return this.ready;
  }

  async analyze(fen: string, options: AnalyzeOptions): Promise<AnalysisResult> {
    if (!this.ready) throw new Error(`Pikafish process #${this.id} is not ready`);

    if (options.multiPv !== this.lastMultiPv) {
      this.write(`setoption name MultiPV value ${options.multiPv}`);
      this.lastMultiPv = options.multiPv;
    }

    this.write(`position fen ${fen}`);
    this.write(`go depth ${options.depth}`);

    const linesByMultiPv = new Map<number, AnalysisLine>();
    let depthReached = 0;

    const search = this.waitFor(
      (line) => line.startsWith('bestmove'),
      (line) => {
        const info = parseInfoLine(line);
        if (!info || info.multipv === undefined || info.pv === undefined || info.scoreType === undefined) {
          return;
        }
        depthReached = Math.max(depthReached, info.depth ?? depthReached);
        linesByMultiPv.set(info.multipv, {
          multiPv: info.multipv,
          depth: info.depth ?? depthReached,
          scoreType: info.scoreType,
          scoreValue: info.scoreValue ?? 0,
          pvMoves: info.pv,
        });
      },
    );

    const bestMoveLine = await this.withTimeout(search, options.timeoutMs);
    const parsed = parseBestMoveLine(bestMoveLine);

    return {
      bestMove: parsed?.bestMove ?? null,
      ponder: parsed?.ponder,
      depthReached,
      lines: [...linesByMultiPv.values()].sort((a, b) => a.multiPv - b.multiPv),
    };
  }

  /** Races `search` against `timeoutMs`; on timeout, sends `stop` (which
   * makes the engine report `bestmove` almost immediately) and gives it one
   * short grace period before giving up for real. */
  private async withTimeout(search: Promise<string>, timeoutMs: number): Promise<string> {
    const stopTimer = setTimeout(() => this.write('stop'), timeoutMs);

    const grace = new Promise<never>((_, reject) => {
      setTimeout(
        () => reject(new Error(`Pikafish process #${this.id} did not respond after "stop"`)),
        timeoutMs + 2_000,
      );
    });

    try {
      return await Promise.race([search, grace]);
    } finally {
      clearTimeout(stopTimer);
    }
  }

  async stop(): Promise<void> {
    this.rl?.close();
    this.child?.kill();
  }
}
