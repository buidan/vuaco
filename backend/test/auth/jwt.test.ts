import jwt from 'jsonwebtoken';
import { describe, expect, it } from 'vitest';

import { InvalidTokenError, signAuthToken, verifyAuthToken } from '../../src/auth/jwt';

describe('jwt', () => {
  it('round-trips a signed token', () => {
    const token = signAuthToken({ sub: 'user-1', username: 'Dan' });
    const payload = verifyAuthToken(token);
    expect(payload).toEqual({ sub: 'user-1', username: 'Dan' });
  });

  it('rejects a garbage token', () => {
    expect(() => verifyAuthToken('not-a-real-token')).toThrow(InvalidTokenError);
  });

  it('rejects a token signed with a different secret', () => {
    const foreignToken = jwt.sign({ sub: 'x', username: 'y' }, 'some-other-secret');
    expect(() => verifyAuthToken(foreignToken)).toThrow(InvalidTokenError);
  });
});
