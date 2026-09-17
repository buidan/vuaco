import jwt from 'jsonwebtoken';

import { config } from '../config';

export interface AuthTokenPayload {
  sub: string; // user id
  username: string;
}

export function signAuthToken(payload: AuthTokenPayload): string {
  return jwt.sign(payload, config.jwtSecret, { expiresIn: config.jwtExpiresIn as jwt.SignOptions['expiresIn'] });
}

export class InvalidTokenError extends Error {}

export function verifyAuthToken(token: string): AuthTokenPayload {
  try {
    const decoded = jwt.verify(token, config.jwtSecret);
    if (typeof decoded === 'string' || !decoded.sub || typeof decoded.username !== 'string') {
      throw new InvalidTokenError('Token payload is missing required fields');
    }
    return { sub: decoded.sub, username: decoded.username };
  } catch (err) {
    if (err instanceof InvalidTokenError) throw err;
    throw new InvalidTokenError(err instanceof Error ? err.message : 'Invalid token');
  }
}
