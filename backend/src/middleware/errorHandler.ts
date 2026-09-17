import { NextFunction, Request, Response } from 'express';
import { ZodError } from 'zod';

export class HttpError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export function errorHandler(err: unknown, req: Request, res: Response, _next: NextFunction): void {
  if (err instanceof ZodError) {
    res.status(400).json({ error: 'invalid_request', details: err.issues });
    return;
  }

  if (err instanceof HttpError) {
    res.status(err.status).json({ error: err.message });
    return;
  }

  const message = err instanceof Error ? err.message : 'Unknown error';
  req.log?.error({ err }, 'unhandled request error');

  if (message.toLowerCase().includes('timed out')) {
    res.status(504).json({ error: 'engine_timeout', message });
    return;
  }

  res.status(500).json({ error: 'internal_error', message });
}
