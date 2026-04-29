import crypto from 'crypto';

/**
 * Calculates the current 30-second time slot.
 */
export function getCurrentTimeSlot(): number {
  return Math.floor(Date.now() / 1000 / 30);
}

/**
 * Generates the rolling hash ID based on the userId, secret key, and time slot.
 */
export function generateRollingHash(userId: string, baseSecretKey: string, timeSlot: number): string {
  const data = `${userId}${baseSecretKey}${timeSlot}`;
  return crypto.createHash('sha256').update(data).digest('hex').toLowerCase().substring(0, 20);
}

/**
 * Generates a random base secret key for new users.
 */
export function generateBaseSecretKey(): string {
  return crypto.randomBytes(32).toString('hex');
}
