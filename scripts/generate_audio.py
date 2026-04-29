import sys
import os
from gtts import gTTS
from pydub import AudioSegment

def generate_audio(text, output_path):
    temp_mp3 = output_path.replace('.wav', '.mp3')
    
    try:
        # Generate speech using gTTS
        tts = gTTS(text=text, lang='en')
        tts.save(temp_mp3)
        
        # Load the MP3 with pydub
        audio = AudioSegment.from_mp3(temp_mp3)
        
        # Optimize for ESP32:
        # - 11025 Hz sample rate
        # - Mono (1 channel)
        # - 8-bit sample width (1 byte)
        # - Reduce volume (-10 dB)
        audio = audio.set_frame_rate(11025).set_channels(1).set_sample_width(1)
        audio = audio - 10
        
        # Export as WAV
        audio.export(output_path, format="wav")
        # print success to stdout
        print(f"SUCCESS:{output_path}")
        
    except Exception as e:
        print(f"ERROR:{str(e)}", file=sys.stderr)
        sys.exit(1)
    finally:
        # Cleanup temporary MP3
        if os.path.exists(temp_mp3):
            os.remove(temp_mp3)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python generate_audio.py <text> <output_path.wav>")
        sys.exit(1)
        
    text = sys.argv[1]
    output_path = sys.argv[2]
    generate_audio(text, output_path)
