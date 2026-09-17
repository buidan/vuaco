import { NextFunction, Request, Response } from 'express';

import { AuthTokenPayload, InvalidTokenError, verifyAuthToken } from './jwt';

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      user?: AuthTokenPayload;
    }
  }
}

function extractBearerToken(header: string | undefined): string | null {
  if (!header) return null;
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) return null;
  return token;
}

/** Requires a valid `Authorization: Bearer <token>` header, attaching the
 * decoded payload to `req.user`. Guest tokens only (see jwt.ts) - there is
 * no password/refresh flow in this phase. */
export function requireAuth(req: Request, res: Response, next: NextFunction): void {
  const token = extractBearerToken(req.header('authorization'));
  if (!token) {
    res.status(401).json({ error: 'unauthorized', message: 'Missing bearer token' });
    return;
  }
  try {
    req.user = verifyAuthToken(token);
    next();
  } catch (err) {
    if (err instanceof InvalidTokenError) {
      res.status(401).json({ error: 'unauthorized', message: 'Invalid or expired token' });
      return;
    }
    throw err;
  }
}
