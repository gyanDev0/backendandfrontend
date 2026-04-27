import { Request, Response } from 'express';
import { db } from '../config/firebase';
import { getCurrentTimeSlot, generateRollingHash } from '../utils/cryptoUtils';
import { generateAttendanceAudio } from '../utils/ttsUtils';
import { io } from '../server';

export const markAttendance = async (req: Request, res: Response): Promise<void> => {
  try {
    if (!db) {
      res.status(500).json({ error: 'Database is not initialized. Missing Service Account.' });
      return;
    }

    // Support both 'uuid' and 'rolling_id' for backward compatibility
    const { uuid, rolling_id, device_id } = req.body;
    const hashToValidate = uuid || rolling_id;

    if (!hashToValidate || !device_id) {
      res.status(400).json({ error: 'Missing required fields: uuid/rolling_id, device_id' });
      return;
    }

    const currentTimeSlot = getCurrentTimeSlot();
    // Check current, previous, and next slots to account for time drift
    const slotsToCheck = [currentTimeSlot, currentTimeSlot - 1, currentTimeSlot + 1];

    const usersSnapshot = await db.collection('users').get();

    let matchedUser: any = null;
    let matchedUserId: string = '';

    searchLoop: for (const doc of usersSnapshot.docs) {
      const user = doc.data();
      for (const slot of slotsToCheck) {
        const expectedHash = generateRollingHash(user.user_id, user.base_secret_key, slot);
        if (expectedHash === hashToValidate) {
          matchedUser = user;
          matchedUserId = doc.id;
          break searchLoop;
        }
      }
    }

    if (!matchedUser) {
      res.status(401).json({ status: 'error', message: 'Invalid or expired UUID' });
      return;
    }

    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
    const docId = `${matchedUserId}_${today}`;
    const attendanceRef = db.collection('attendances').doc(docId);
    
    const existingAttendance = await attendanceRef.get();

    // Generate Audio URL (either fresh or from cache)
    const audioUrlPath = await generateAttendanceAudio(matchedUser.name, matchedUser.user_id);
    const fullAudioUrl = `${req.protocol}://${req.get('host')}${audioUrlPath}`;

    if (existingAttendance.exists) {
      res.status(200).json({ 
        status: 'success',
        message: 'Attendance already marked for today',
        name: matchedUser.name,
        user_id: matchedUser.user_id,
        audio_url: fullAudioUrl,
        already_marked: true
      });
      return;
    }

    const now = new Date();
    const time = now.toISOString().split('T')[1].split('.')[0]; // HH:mm:ss

    const attendanceData = {
      user_id: matchedUserId,
      real_user_id: matchedUser.user_id,
      name: matchedUser.name,
      device_id,
      date: today,
      time,
      created_at: now.toISOString()
    };

    await attendanceRef.set(attendanceData);

    // Emit real-time update to the Mobile App
    io.to(matchedUser.user_id).emit('attendance_marked', {
      status: 'success',
      name: matchedUser.name,
      time: time,
      date: today
    });

    res.status(200).json({
      status: 'success',
      message: 'Attendance marked successfully',
      name: matchedUser.name,
      user_id: matchedUser.user_id,
      audio_url: fullAudioUrl
    });
  } catch (error: any) {
    console.error('Attendance error:', error);
    res.status(500).json({ status: 'error', error: error.message || 'Internal server error' });
  }
};

export const getHistory = async (req: Request, res: Response): Promise<void> => {
  try {
    if (!db) {
      res.status(500).json({ error: 'Database is not initialized.' });
      return;
    }

    const userId = (req as any).user?.user_id; 
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const historySnapshot = await db.collection('attendances')
      .where('real_user_id', '==', userId)
      .orderBy('created_at', 'desc')
      .get();

    const history = historySnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    res.json({ history });
  } catch (error) {
    console.error('Get history error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};
