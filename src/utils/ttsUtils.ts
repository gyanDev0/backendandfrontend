import gTTS from 'node-gtts';
import path from 'path';
import fs from 'fs-extra';

const tts = new gTTS('en');

/**
 * Generates an MP3 file for a user's attendance announcement.
 * Uses caching to avoid repeated TTS generation.
 * @param name User's name
 * @param userId User's ID (used for filename)
 * @returns Path to the generated file relative to public/audio
 */
export const generateAttendanceAudio = async (name: string, userId: string): Promise<string> => {
  const fileName = `${userId}.mp3`; 
  const publicAudioDir = path.join(__dirname, '../../public/audio');
  const filePath = path.join(publicAudioDir, fileName);

  await fs.ensureDir(publicAudioDir);

  if (await fs.pathExists(filePath)) {
    return `/audio/${fileName}`;
  }

  const text = `${name}, attendance marked successfully.`;
  
  return new Promise((resolve, reject) => {
    tts.save(filePath, text, () => {
      console.log(`Generated audio for ${name}: ${filePath}`);
      resolve(`/audio/${fileName}`);
    });
  });
};
