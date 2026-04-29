import { db } from '../config/firebase';
import { generateRollingHash, getCurrentTimeSlot } from './cryptoUtils';

export interface UUIDRecord {
  userId: string;
  name: string;
  expectedHash: string;
}

class UUIDManager {
  private cache: Map<string, UUIDRecord> = new Map();
  private activeUsers: any[] = [];
  private lastSlot: number = 0;
  private timer: NodeJS.Timeout | null = null;
  public ioRef: any = null;

  public async init() {
    this.reloadUsers();
    // Reload users periodically in case of new registrations
    setInterval(() => this.reloadUsers(), 60000); 

    // Generate UUID every second, check time slot boundary
    this.timer = setInterval(() => this.tick(), 1000);
  }

  private async reloadUsers() {
    if (!db) return;
    try {
      const snapshot = await db.collection('users').get();
      this.activeUsers = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    } catch (e) {
      console.error('Error reloading users for UUID Manager:', e);
    }
  }

  private tick() {
    const currentSlot = getCurrentTimeSlot();
    if (this.lastSlot !== currentSlot) {
      this.lastSlot = currentSlot;
      this.cache.clear();
      
      for (const user of this.activeUsers) {
        if (!user.user_id || !user.base_secret_key) continue;
        const hash = generateRollingHash(user.user_id, user.base_secret_key, currentSlot);
        this.cache.set(hash, {
          userId: user.user_id,
          name: user.name,
          expectedHash: hash
        });
        
        // Push over sockets if io is set
        if (this.ioRef) {
          this.ioRef.to(user.user_id).emit('uuid_update', { uuid: hash, slot: currentSlot });
        }
      }
      console.log(`[UUIDManager] Generated new rotation of hashes (Slot: ${currentSlot}, Users: ${this.cache.size})`);
    }
  }

  public validateHash(hash: string): UUIDRecord | undefined {
    return this.cache.get(hash.toLowerCase());
  }

  // Gets the exact current DB-backed UUID for a user
  public getCurrentHashForUser(userId: string): string | null {
    for (const [hash, record] of this.cache.entries()) {
      if (record.userId === userId) {
        return hash;
      }
    }
    // Alternatively calculate on the fly for immediate fetch
    const user = this.activeUsers.find(u => u.user_id === userId);
    if (!user) return null;
    return generateRollingHash(user.user_id, user.base_secret_key, getCurrentTimeSlot());
  }
}

export const uuidManager = new UUIDManager();
