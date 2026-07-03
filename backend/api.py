from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import database
import translator_engine
import speech_engine
import io
import time

app = Flask(__name__)
CORS(app)

database.init_db()

@app.route('/', methods=['GET'])
def index():
    return jsonify({
        'status': 'online',
        'project': 'Universal AI Translator Backend API',
        'creator': 'Ssamarth Kanade'
    })

@app.route('/languages', methods=['GET'])
def get_languages():
    return jsonify(translator_engine.get_supported_languages())

@app.route('/translate', methods=['POST'])
def translate():
    start_time = time.time()
    
    data = request.json or {}
    text = data.get('text', '')
    target_lang = data.get('target_lang', 'es')
    source_lang = data.get('source_lang', 'auto')
    mode = data.get('mode', 'Text')
    tone_modifier = data.get('tone_modifier', 'Original')
    
    if not text.strip():
        return jsonify({'error': 'No text provided'}), 400
        
    processed_text = text
    if tone_modifier != 'Original':
        processed_text = translator_engine.rewrite_tone_shifter(text, tone_modifier)
        
    translated = translator_engine.translate_text(processed_text, target_lang, source_lang)
    
    # Run unique AI insights
    analysis = translator_engine.analyze_sentiment_and_tone(processed_text)
    flashcards = translator_engine.extract_vocab_flashcards(processed_text)
    
    # Calculate ML Confidence and Latency
    latency = round(time.time() - start_time, 2)
    confidence = translator_engine.calculate_ml_confidence(processed_text)
    
    database.save_translation(source_lang, target_lang, text, translated, f"{mode} ({tone_modifier})")
    
    return jsonify({
        'original_text': text,
        'processed_text': processed_text,
        'translated_text': translated,
        'source_lang': source_lang,
        'target_lang': target_lang,
        'analysis': analysis,
        'flashcards': flashcards,
        'ml_confidence': confidence,
        'latency': latency,
        'engine': 'DeepTranslator Neural Machine (Google Translate Engine)'
      })

@app.route('/translate_pdf', methods=['POST'])
def translate_pdf_api():
    start_time = time.time()
    if 'file' not in request.files:
        return jsonify({'error': 'No file uploaded'}), 400
    file = request.files['file']
    target_lang = request.form.get('target_lang', 'es')
    source_lang = request.form.get('source_lang', 'auto')
    
    raw_text, translated = translator_engine.translate_pdf(file, target_lang, source_lang)
    analysis = translator_engine.analyze_sentiment_and_tone(raw_text)
    flashcards = translator_engine.extract_vocab_flashcards(raw_text)
    
    latency = round(time.time() - start_time, 2)
    confidence = translator_engine.calculate_ml_confidence(raw_text)
    
    if translated:
        database.save_translation(source_lang, target_lang, raw_text, translated, "PDF")
        
    return jsonify({
        'original_text': raw_text,
        'translated_text': translated,
        'analysis': analysis,
        'flashcards': flashcards,
        'ml_confidence': confidence,
        'latency': latency,
        'engine': 'PyMuPDF Text Extractor + DeepTranslator'
    })

@app.route('/translate_ocr', methods=['POST'])
def translate_ocr_api():
    start_time = time.time()
    if 'file' not in request.files:
        return jsonify({'error': 'No file uploaded'}), 400
    file = request.files['file']
    target_lang = request.form.get('target_lang', 'es')
    source_lang = request.form.get('source_lang', 'auto')
    
    img_bytes = file.read()
    raw_text, translated = translator_engine.translate_image_ocr(img_bytes, target_lang, source_lang)
    analysis = translator_engine.analyze_sentiment_and_tone(raw_text)
    flashcards = translator_engine.extract_vocab_flashcards(raw_text)
    
    latency = round(time.time() - start_time, 2)
    confidence = translator_engine.calculate_ml_confidence(raw_text)
    
    if translated:
        database.save_translation(source_lang, target_lang, raw_text, translated, "OCR")
        
    return jsonify({
        'original_text': raw_text,
        'translated_text': translated,
        'analysis': analysis,
        'flashcards': flashcards,
        'ml_confidence': confidence,
        'latency': latency,
        'engine': 'EasyOCR/Pytesseract Scanner + DeepTranslator'
    })

@app.route('/translate_voice', methods=['POST'])
def translate_voice_api():
    start_time = time.time()
    if 'file' not in request.files:
        return jsonify({'error': 'No file uploaded'}), 400
    file = request.files['file']
    target_lang = request.form.get('target_lang', 'es')
    source_lang = request.form.get('source_lang', 'auto')
    
    audio_bytes = file.read()
    raw_text = speech_engine.speech_to_text_from_file(audio_bytes)
    translated = translator_engine.translate_text(raw_text, target_lang, source_lang)
    
    latency = round(time.time() - start_time, 2)
    confidence = translator_engine.calculate_ml_confidence(raw_text)
    
    if translated:
        database.save_translation(source_lang, target_lang, raw_text, translated, "Speech")
        
    return jsonify({
        'original_text': raw_text,
        'translated_text': translated,
        'ml_confidence': confidence,
        'latency': latency,
        'engine': 'SpeechRecognition Google Transcriber + DeepTranslator'
      })

@app.route('/translate_video', methods=['POST'])
def translate_video_api():
    start_time = time.time()
    if 'file' not in request.files:
        return jsonify({'error': 'No file uploaded'}), 400
    file = request.files['file']
    target_lang = request.form.get('target_lang', 'es')
    source_lang = request.form.get('source_lang', 'auto')
    
    import video_translator
    video_bytes = file.read()
    raw_text, translated = video_translator.translate_video_file(video_bytes, target_lang, source_lang)
    analysis = translator_engine.analyze_sentiment_and_tone(raw_text)
    flashcards = translator_engine.extract_vocab_flashcards(raw_text)
    
    latency = round(time.time() - start_time, 2)
    confidence = translator_engine.calculate_ml_confidence(raw_text)
    
    if translated:
        database.save_translation(source_lang, target_lang, raw_text, translated, "Video")
        
    return jsonify({
        'original_text': raw_text,
        'translated_text': translated,
        'analysis': analysis,
        'flashcards': flashcards,
        'ml_confidence': confidence,
        'latency': latency,
        'engine': 'FFmpeg Audio Extractor + DeepTranslator'
    })

@app.route('/tts', methods=['GET'])
def get_tts():
    text = request.args.get('text', '')
    lang = request.args.get('lang', 'en')
    if not text:
        return 'Missing text parameter', 400
        
    audio_fp = speech_engine.text_to_speech(text, lang)
    if not audio_fp:
        return 'Failed to generate speech', 500
        
    return send_file(
        audio_fp,
        mimetype="audio/mp3",
        as_attachment=False,
        download_name="speech.mp3"
    )

@app.route('/history', methods=['GET'])
def get_history():
    rows = database.get_history(limit=20)
    history_list = []
    for r in rows:
        history_list.append({
            'timestamp': r[0],
            'source_lang': r[1],
            'target_lang': r[2],
            'original_text': r[3],
            'translated_text': r[4],
            'mode': r[5]
        })
    return jsonify(history_list)

@app.route('/clear_history', methods=['POST'])
def clear_history_api():
    database.clear_history()
    return jsonify({'status': 'success'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
