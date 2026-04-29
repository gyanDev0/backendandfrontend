import { Router } from 'express';
import { register, login } from './controllers/authController';
import { markAttendance, getHistory, getCurrentUuid } from './controllers/attendanceController';
import { authMiddleware } from './middleware/auth';

const router = Router();

// Authentication Routes
router.post('/register', register);
router.post('/login', login);

// ESP32 Attendance Route (No JWT required, secured by rolling hash)
router.post('/attendance', markAttendance);

// App Dashboard Routes (Protected)
router.get('/attendance/history', authMiddleware, getHistory);
router.get('/attendance/uuid', getCurrentUuid);

export default router;
