import express from 'express';
import cors from 'cors';
import http from 'http';
import { Server } from 'socket.io';
import path from 'path';
import fs from 'fs';
import routes from './routes';
import dotenv from 'dotenv';
import { uuidManager } from './utils/uuidManager';

dotenv.config();

const app = express();
const server = http.createServer(app);
export const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Serve static files (for audio)
const publicPath = path.join(__dirname, '../public');
if (!fs.existsSync(publicPath)) {
  fs.mkdirSync(publicPath, { recursive: true });
}
app.use('/audio', express.static(path.join(publicPath, 'audio')));

// Simple Request Logger
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

// Root route
app.get('/', (req, res) => {
  res.status(200).json({ 
    status: 'online', 
    message: 'Ultimate Smart Attendance API is running!',
    timestamp: new Date().toISOString()
  });
});

// API Routes
app.use('/api', routes);

// Socket.IO Connection
io.on('connection', (socket) => {
  console.log('A user connected:', socket.id);
  
  socket.on('join_user', (userId) => {
    socket.join(userId);
    console.log(`User ${userId} joined their private room.`);
  });

  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
  });
});

server.listen(PORT, async () => {
  console.log(`Server is running on port ${PORT}`);
  uuidManager.ioRef = io;
  await uuidManager.init();
});
