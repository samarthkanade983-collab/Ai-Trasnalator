import streamlit as st
import database
import translator_engine
import speech_engine
import os

# Set page config
st.set_page_config(
    page_title="AI Language Translator",
    page_icon="🔮",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Initialize Database
database.init_db()

# Load and inject custom CSS
def load_css(file_name):
    if os.path.exists(file_name):
        with open(file_name) as f:
            st.markdown(f"<style>{f.read()}</style>", unsafe_allow_html=True)

load_css("style.css")

# App Header
st.markdown("<h1 class='gradient-text'>🔮 Universal AI Translator</h1>", unsafe_allow_html=True)
st.markdown("<p class='subtitle-text'>Translate Text, Documents, Images, and Voice using Next-Gen AI & NLP</p>", unsafe_allow_html=True)

# Languages setup
languages_dict = translator_engine.get_supported_languages()
lang_names = list(languages_dict.values())
lang_codes = list(languages_dict.keys())

# Sidebar Configuration & History
with st.sidebar:
    st.markdown("### ⚙️ Settings")
    
    translation_provider = st.selectbox(
        "Translation Provider",
        ["Google Translate (Deep-Translator)", "MyMemory API"]
    )
    
    st.markdown("---")
    st.markdown("### 📜 Translation History")
    
    if st.button("🗑️ Clear History"):
        database.clear_history()
        st.toast("History cleared successfully!")
        
    history = database.get_history(limit=10)
    if history:
        for row in history:
            timestamp, src, tgt, orig, trans, mode = row
            src_name = languages_dict.get(src, src.upper())
            tgt_name = languages_dict.get(tgt, tgt.upper())
            
            st.markdown(
                f"""
                <div style='background: rgba(255,255,255,0.05); padding: 10px; border-radius: 8px; margin-bottom: 8px;'>
                     <span class='mode-tag'>{mode}</span> 
                     <span class='lang-tag'>{src_name} ➔ {tgt_name}</span>
                     <p style='margin: 4px 0 0 0; font-size: 0.85rem; color: #cbd5e1; text-overflow: ellipsis; overflow: hidden; white-space: nowrap;'>
                          <b>Original:</b> {orig[:40]}...
                     </p>
                     <p style='margin: 2px 0 0 0; font-size: 0.85rem; color: #a5b4fc; text-overflow: ellipsis; overflow: hidden; white-space: nowrap;'>
                          <b>Translated:</b> {trans[:40]}...
                     </p>
                </div>
                """,
                unsafe_allow_html=True
            )
    else:
        st.info("No translation history yet.")

# Main app layout splits
col_source, col_target = st.columns(2)

with col_source:
    st.markdown("<div class='glass-card'>", unsafe_allow_html=True)
    st.subheader("Source Input")
    
    source_lang_name = st.selectbox("Source Language", lang_names, index=0)  # Default: Auto Detect
    source_lang_code = lang_codes[lang_names.index(source_lang_name)]
    
    # Input tabs for different file types
    tab_text, tab_doc, tab_img, tab_voice = st.tabs([
        "📝 Text", "📄 Document (PDF)", "🖼️ Image (OCR)", "🎙️ Voice File"
    ])
    
    input_text = ""
    mode = "Text"
    
    with tab_text:
        input_text = st.text_area("Enter text to translate...", height=200, key="text_input_area")
        
    with tab_doc:
        uploaded_pdf = st.file_uploader("Upload a PDF file", type=["pdf"])
        if uploaded_pdf is not None:
            mode = "PDF"
            with st.spinner("Extracting text from PDF..."):
                raw_text, _ = translator_engine.translate_pdf(uploaded_pdf, "en") # Temp read
                input_text = st.text_area("Extracted Document Text", value=raw_text, height=200)
                
    with tab_img:
        uploaded_img = st.file_uploader("Upload an Image", type=["png", "jpg", "jpeg"])
        if uploaded_img is not None:
            mode = "OCR"
            with st.spinner("Extracting text from image via OCR..."):
                img_bytes = uploaded_img.read()
                raw_text, _ = translator_engine.translate_image_ocr(img_bytes, "en")
                input_text = st.text_area("Extracted Image Text", value=raw_text, height=200)
                
    with tab_voice:
        uploaded_audio = st.file_uploader("Upload Audio (WAV/MP3 format)", type=["wav", "mp3"])
        if uploaded_audio is not None:
            mode = "Voice"
            with st.spinner("Transcribing audio..."):
                audio_bytes = uploaded_audio.read()
                raw_text = speech_engine.speech_to_text_from_file(audio_bytes)
                input_text = st.text_area("Transcribed Text", value=raw_text, height=200)
                
    st.markdown("</div>", unsafe_allow_html=True)

# Process translation
translated_text = ""
with col_target:
    st.markdown("<div class='glass-card'>", unsafe_allow_html=True)
    st.subheader("Translation Output")
    
    target_lang_name = st.selectbox("Target Language", lang_names, index=1)  # Default: English
    target_lang_code = lang_codes[lang_names.index(target_lang_name)]
    
    if st.button("✨ Translate", use_container_width=True):
        if input_text.strip():
            with st.spinner("Translating..."):
                # Handle auto translation if source is Auto Detect
                translated_text = translator_engine.translate_text(
                    input_text, target_lang_code, source_lang_code
                )
                
                # Save to database
                database.save_translation(
                    source_lang_code, target_lang_code, input_text, translated_text, mode
                )
                
                # Refresh page to show updated history in sidebar
                st.rerun()
        else:
            st.warning("Please provide input text or upload a file.")
            
    # Retrieve the last translation output from session state or display current if just translated
    # To keep the layout clean, we can display output in a nice box
    last_translation = ""
    last_original = ""
    history_last = database.get_history(limit=1)
    if history_last:
        last_translation = history_last[0][4]  # index 4 is translated_text
        last_original = history_last[0][3]     # index 3 is original_text
    
    output_display = st.text_area("Translated Output", value=last_translation, height=200, disabled=False)
    
    # Text-to-Speech playback for translated text
    if last_translation:
        st.write("🔊 Listen to Translation:")
        audio_file = speech_engine.text_to_speech(last_translation, target_lang_code)
        if audio_file:
            st.audio(audio_file, format="audio/mp3")
            
    st.markdown("</div>", unsafe_allow_html=True)

# NLP Feature Section (spaCy Analysis)
if last_translation and last_original:
    st.markdown("### 🧠 AI NLP Text Analysis")
    with st.expander("Show detailed NLP Analysis of original text"):
        analysis = translator_engine.perform_nlp_analysis(last_original)
        if isinstance(analysis, dict):
            c1, c2, c3 = st.columns(3)
            with c1:
                st.metric("Total Word Count", analysis.get("word_count", 0))
                st.metric("Sentence Count", analysis.get("sentence_count", 0))
            with c2:
                st.markdown("**Top Nouns Found:**")
                st.write(", ".join(analysis.get("top_nouns", [])) if analysis.get("top_nouns") else "None")
                st.markdown("**Top Verbs Found:**")
                st.write(", ".join(analysis.get("top_verbs", [])) if analysis.get("top_verbs") else "None")
            with c3:
                st.markdown("**Named Entities:**")
                if analysis.get("entities"):
                    for ent, label in list(set(analysis.get("entities", [])))[:5]:
                        st.markdown(f"- `{ent}` ({label})")
                else:
                    st.write("No major entities recognized.")
        else:
            st.info(analysis)
