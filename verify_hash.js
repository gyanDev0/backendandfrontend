const crypto = require('crypto');

function generateRollingHash(userId, baseSecretKey, timeSlot) {
  const data = `${userId}${baseSecretKey}${timeSlot}`;
  return crypto.createHash('sha256').update(data).digest('hex');
}

const userId = "USER123";
const baseSecretKey = "super_secret_base_key";
const timeSlot = 12345678;

const hash = generateRollingHash(userId, baseSecretKey, timeSlot);

console.log("User ID:", userId);
console.log("Base Secret Key:", baseSecretKey);
console.log("Time Slot:", timeSlot);
console.log("Generated Hash:", hash);
