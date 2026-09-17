import { PikafishProcess, PikafishProcessOptions } from './pikafishProcess';
import { AnalysisResult, AnalyzeOptions } from './types';

interface QueuedTask {
  fen: string;
  options: AnalyzeOptions;
  resolve: (result: AnalysisResult) => void;
  reject: (err: unknown) => void;
}

/**
 * Fixed-size pool of Pikafish processes. Each process handles one analysis
 * at a time, so concurrent `/engine/analyze` requests beyond the pool size
 * queue up rather than spawning unbounded engine processes.
 */
export class PikafishPool {
  private readonly workers: PikafishProcess[] = [];
  private readonly freeWorkers: PikafishProcess[] = [];
  private readonly queue: QueuedTask[] = [];

  constructor(
    private readonly size: number,
    private readonly processOptions: PikafishProcessOptions,
  ) {}

  async start(): Promise<void> {
    for (let i = 0; i < this.size; i++) {
      const worker = new PikafishProcess(i, this.processOptions);
      await worker.start();
      this.workers.push(worker);
      this.freeWorkers.push(worker);
    }
  }

  async stop(): Promise<void> {
    await Promise.all(this.workers.map((w) => w.stop()));
  }

  get poolSize(): number {
    return this.workers.length;
  }

  get pendingCount(): number {
    return this.queue.length;
  }

  analyze(fen: string, options: AnalyzeOptions): Promise<AnalysisResult> {
    return new Promise((resolve, reject) => {
      const task: QueuedTask = { fen, options, resolve, reject };
      const worker = this.freeWorkers.pop();
      if (worker) {
        this.run(worker, task);
      } else {
        this.queue.push(task);
      }
    });
  }

  private run(worker: PikafishProcess, task: QueuedTask): void {
    worker
      .analyze(task.fen, task.options)
      .then(task.resolve, task.reject)
      .finally(() => {
        const next = this.queue.shift();
        if (next) {
          this.run(worker, next);
        } else {
          this.freeWorkers.push(worker);
        }
      });
  }
}
