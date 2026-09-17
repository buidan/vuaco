import { randomInt } from 'node:crypto';

import { config } from '../config';

// Excludes visually ambiguous characters (0/O, 1/I/L) so a PIN read aloud
// or handwritten is unambiguous.
const PIN_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

export function generatePin(length: number = config.roomPinLength): string {
  let pin = '';
  for (let i = 0; i < length; i++) {
    pin += PIN_ALPHABET[randomInt(PIN_ALPHABET.length)];
  }
  return pin;
}
