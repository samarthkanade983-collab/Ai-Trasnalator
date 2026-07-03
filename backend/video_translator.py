import os
import subprocess
import speech_recognition as sr
from deep_translator import GoogleTranslator
import tempfile

def extract_audio_from_video(video_bytes):
    """
    Extracts raw audio from uploaded video bytes using FFmpeg.
    """
    temp_video = tempfile.NamedTemporaryFile(delete=False, suffix='.mp4')
    temp_audio = tempfile.NamedTemporaryFile(delete=False, suffix='.wav')
    try:
        temp_video.write(video_bytes)
        temp_video.close()
        temp_audio.close()
        
        # Call local FFmpeg binary to extract audio from video stream
        cmd = [
            'ffmpeg', '-y', '-i', temp_video.name,
            '-vn', '-acodec', 'pcm_s16le', '-ar', '16000', '-ac', '1',
            temp_audio.name
        ]
        # Hide console window popup on Windows
        startupinfo = None
        if os.name == 'nt':
            startupinfo = subprocess.STARTUPINFO()
            startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, startupinfo=startupinfo)
        
        with open(temp_audio.name, 'rb') as f:
            audio_bytes = f.read()
            
        return audio_bytes
    except Exception as e:
        print(f"FFmpeg extraction error: {e}")
        return None
    finally:
        try:
            os.unlink(temp_video.name)
            os.unlink(temp_audio.name)
        except _:
            pass

def translate_video_file(video_bytes, target_lang, source_lang='auto'):
    """
    Extracts audio from video, transcribes it, and translates the transcribed content.
    """
    audio_bytes = extract_audio_from_video(video_bytes)
    if not audio_bytes:
        return "Failed to parse video audio stream. Make sure FFmpeg is installed.", ""
        
    recognizer = sr.Recognizer()
    try:
        import io
        audio_file = io.BytesIO(audio_bytes)
        with sr.AudioFile(audio_file) as source:
            audio_data = recognizer.record(source)
            original_text = recognizer.recognize_google(audio_data)
            
        translator = GoogleTranslator(source=source_lang, target=target_lang)
        translated_text = translator.translate(original_text)
        return original_text, translated_text
    except Exception as e:
        return f"Video Transcription Failed: {str(e)}", ""
