import { Request, Response } from 'express';
import { db } from '../config/firebase';
import { generateAttendanceAudio } from '../utils/ttsUtils';
import { io } from '../server';
import { uuidManager } from '../utils/uuidManager';
import fs from 'fs-extra';
import path from 'path';

export const markAttendance = async (req: Request, res: Response): Promise<void> => {
  try {
    if (!db) {
      res.status(500).json({ error: 'Database is not initialized. Missing Service Account.' });
      return;
    }

    const { uuid, rolling_id, device_id } = req.body;
    const hashToValidate = (uuid || rolling_id)?.toString().toLowerCase();

    if (!hashToValidate || !device_id) {
      res.status(400).json({ error: 'Missing required fields: uuid/rolling_id, device_id' });
      return;
    }

    // NEW FLOW: Fast O(1) lookup against server source-of-truth UUID cache
    const matchedUser = uuidManager.validateHash(hashToValidate);

    if (!matchedUser) {
      res.status(404).json({ status: 'error', message: 'Invalid or expired UUID' });
      return;
    }

    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
    const docId = `${matchedUser.userId}_${today}`;
    const attendanceRef = db.collection('attendances').doc(docId);
    
    const existingAttendance = await attendanceRef.get();

    if (existingAttendance.exists) {
      // Already marked
      const wavFilePath = await generateAttendanceAudio(matchedUser.name, matchedUser.userId, true);
      res.set({
        'Content-Type': 'audio/wav',
        'Content-Length': (await fs.stat(wavFilePath)).size,
        'X-User-Name': matchedUser.name
      });
      res.status(200);
      fs.createReadStream(wavFilePath).pipe(res);
      return;
    }

    const now = new Date();
    const time = now.toISOString().split('T')[1].split('.')[0]; // HH:mm:ss

    const attendanceData = {
      user_id: matchedUser.userId, // Internal doc ID not needed, fallback to standard user_id
      real_user_id: matchedUser.userId,
      name: matchedUser.name,
      device_id,
      date: today,
      time,
      created_at: now.toISOString()
    };

    await attendanceRef.set(attendanceData);

    // Emit real-time update to the Mobile App
    io.to(matchedUser.userId).emit('attendance_marked', {
      status: 'success',
      name: matchedUser.name,
      time: time,
      date: today
    });

    // Generate Success WAV
    const wavFilePath = await generateAttendanceAudio(matchedUser.name, matchedUser.userId, false);
    res.set({
      'Content-Type': 'audio/wav',
      'Content-Length': (await fs.stat(wavFilePath)).size,
      'X-User-Name': matchedUser.name
    });
    res.status(200);
    fs.createReadStream(wavFilePath).pipe(res);
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

export const getCurrentUuid = async (req: Request, res: Response): Promise<void> => {
  const userId = req.query.userId as string;
  if (!userId) {
    res.status(400).json({ error: 'Missing userId' });
    return;
  }
  const uuid = uuidManager.getCurrentHashForUser(userId);
  if (uuid) {
    res.status(200).json({ uuid });
  } else {
    res.status(404).json({ error: 'User not found or UUID not generated' });
  }
};
