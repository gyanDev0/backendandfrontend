import { Request, Response } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { db } from '../config/firebase';
import { generateBaseSecretKey } from '../utils/cryptoUtils';

const JWT_SECRET = process.env.JWT_SECRET || 'super-secret-key-for-dev';

export const register = async (req: Request, res: Response): Promise<void> => {
  try {
    if (!db) {
      res.status(500).json({ error: 'Database is not initialized. Missing Service Account.' });
      return;
    }

    const { name, institution_code, user_id, password } = req.body;

    if (!name || !institution_code || !user_id || !password) {
      res.status(400).json({ error: 'Missing required fields' });
      return;
    }

    // Verify institution exists (Assume 'institutions' collection uses institution_code as document ID or queries it)
    const institutionQuery = await db.collection('institutions')
      .where('institution_code', '==', institution_code)
      .limit(1)
      .get();

    if (institutionQuery.empty) {
      res.status(400).json({ error: 'Invalid institution code' });
      return;
    }

    const institutionId = institutionQuery.docs[0].id;

    // Check if user already exists
    const userRef = db.collection('users').doc(user_id);
    const existingUser = await userRef.get();

    if (existingUser.exists) {
      res.status(400).json({ error: 'User ID already in use' });
      return;
    }

    const password_hash = await bcrypt.hash(password, 10);
    const base_secret_key = generateBaseSecretKey();

    const userData = {
      name,
      institution_id: institutionId,
      user_id,
      password_hash,
      base_secret_key,
      created_at: new Date().toISOString()
    };

    await userRef.set(userData);

    res.status(201).json({
      message: 'User registered successfully',
      user: {
        id: user_id,
        name: name,
        user_id: user_id,
        institution_id: institutionId,
      },
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const login = async (req: Request, res: Response): Promise<void> => {
  try {
    if (!db) {
      res.status(500).json({ error: 'Database is not initialized. Missing Service Account.' });
      return;
    }

    const { user_id, password } = req.body;

    if (!user_id || !password) {
      res.status(400).json({ error: 'Missing credentials' });
      return;
    }

    const userDoc = await db.collection('users').doc(user_id).get();

    if (!userDoc.exists) {
      res.status(401).json({ error: 'Invalid credentials' });
      return;
    }

    const user = userDoc.data()!;

    const isValid = await bcrypt.compare(password, user.password_hash);
    if (!isValid) {
      res.status(401).json({ error: 'Invalid credentials' });
      return;
    }

    const token = jwt.sign(
      { id: userDoc.id, user_id: user.user_id },
      JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.json({
      message: 'Login successful',
      token,
      base_secret_key: user.base_secret_key, // Returned to mobile app securely on login
      user: {
        name: user.name,
        user_id: user.user_id,
      },
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};
