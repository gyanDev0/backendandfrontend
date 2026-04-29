import path from 'path';
import fs from 'fs-extra';
import { exec } from 'child_process';

const publicAudioDir = path.join(__dirname, '../../public/audio');

/**
 * Generates a WAV file for a user's attendance announcement using Python script.
 * @param name User's name
 * @param userId User's ID (used for filename)
 * @param isAlreadyMarked Whether to generate the "already marked" message
 * @returns Path to the generated WAV file directly.
 */
export const generateAttendanceAudio = async (name: string, userId: string, isAlreadyMarked: boolean = false): Promise<string> => {
  const messageType = isAlreadyMarked ? 'already' : 'success';
  const fileName = `${userId}_${messageType}.wav`; 
  const filePath = path.join(publicAudioDir, fileName);

  await fs.ensureDir(publicAudioDir);

  // Return cached file if it already exists
  if (await fs.pathExists(filePath)) {
    return filePath;
  }

  const text = isAlreadyMarked 
    ? `${name} already marked` 
    : `${name} attendance taken successfully`;
  
  const pyScript = path.join(__dirname, '../../scripts/generate_audio.py');

  return new Promise((resolve, reject) => {
    // Add double quotes around text and filepath in windows
    const command = `python "${pyScript}" "${text}" "${filePath}"`;
    
    exec(command, (error, stdout, stderr) => {
      if (error) {
        console.error(`Error generating audio: ${error.message}`);
        console.error(`stderr: ${stderr}`);
        reject(error);
        return;
      }
      if (stdout.includes("SUCCESS")) {
        console.log(`Generated WAV audio: ${filePath}`);
        resolve(filePath);
      } else {
        console.error(`Unexpected output: ${stdout}`);
        reject(new Error("Python script failed generating audio."));
      }
    });
  });
};
