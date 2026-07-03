import sqlite3
from datetime import datetime

DB_NAME = "history.db"

def init_db():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS translations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT,
            source_lang TEXT,
            target_lang TEXT,
            original_text TEXT,
            translated_text TEXT,
            mode TEXT
        )
    """)
    conn.commit()
    conn.close()

def save_translation(source_lang, target_lang, original_text, translated_text, mode):
    init_db()
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    cursor.execute("""
        INSERT INTO translations (timestamp, source_lang, target_lang, original_text, translated_text, mode)
        VALUES (?, ?, ?, ?, ?, ?)
    """, (timestamp, source_lang, target_lang, original_text, translated_text, mode))
    conn.commit()
    conn.close()

def get_history(limit=50):
    init_db()
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    cursor.execute("""
        SELECT timestamp, source_lang, target_lang, original_text, translated_text, mode 
        FROM translations 
        ORDER BY id DESC 
        LIMIT ?
    """, (limit,))
    rows = cursor.fetchall()
    conn.close()
    return rows

def clear_history():
    init_db()
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    cursor.execute("DELETE FROM translations")
    conn.commit()
    conn.close()
