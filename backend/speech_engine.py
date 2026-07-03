from gtts import gTTS
import io
import os
import subprocess
import tempfile
import speech_recognition as sr

def convert_audio_to_wav(audio_file_bytes):
    """
    Converts generic audio (MP3, M4A, etc.) to PCM WAV 16kHz mono using FFmpeg.
    """
    temp_input = tempfile.NamedTemporaryFile(delete=False, suffix='.bin')
    temp_output = tempfile.NamedTemporaryFile(delete=False, suffix='.wav')
    
    try:
        temp_input.write(audio_file_bytes)
        temp_input.close()
        temp_output.close()
        
        cmd = [
            'ffmpeg', '-y', '-i', temp_input.name,
            '-acodec', 'pcm_s16le', '-ar', '16000', '-ac', '1',
            temp_output.name
        ]
        
        startupinfo = None
        if os.name == 'nt':
            startupinfo = subprocess.STARTUPINFO()
            startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            
        res = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, startupinfo=startupinfo)
        if res.returncode != 0:
            return None
            
        with open(temp_output.name, 'rb') as f:
            wav_bytes = f.read()
        return wav_bytes
    except Exception as e:
        print(f"Audio conversion failed: {e}")
        return None
    finally:
        try:
            os.unlink(temp_input.name)
            os.unlink(temp_output.name)
        except Exception:
            pass

def text_to_speech(text, lang_code):
    """
    Generate an audio file in-memory using gTTS.
    """
    try:
        clean_lang = lang_code.split('-')[0]
        tts = gTTS(text=text, lang=clean_lang, slow=False)
        fp = io.BytesIO()
        tts.write_to_fp(fp)
        fp.seek(0)
        return fp
    except Exception as e:
        print(f"TTS Error: {e}")
        return None

def speech_to_text_from_file(audio_file_bytes):
    """
    Recognize speech from an uploaded audio file. Automatically converts to WAV if possible.
    """
    recognizer = sr.Recognizer()
    
    # Try converting to WAV first to handle MP3/M4A/etc.
    wav_bytes = convert_audio_to_wav(audio_file_bytes)
    if wav_bytes is None:
        # Fallback to original bytes
        wav_bytes = audio_file_bytes
        
    try:
        audio_file = io.BytesIO(wav_bytes)
        with sr.AudioFile(audio_file) as source:
            audio_data = recognizer.record(source)
            text = recognizer.recognize_google(audio_data)
            return text
    except Exception as e:
        return f"Speech recognition failed: {str(e)}"
