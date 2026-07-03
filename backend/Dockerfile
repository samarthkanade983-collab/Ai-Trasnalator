FROM python:3.10-slim

# Install system dependencies, including FFmpeg for video parsing
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy python dependency list and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Download lightweight spacy model for vocabulary tracking
RUN python -m spacy download en_core_web_sm

# Copy the rest of the application files
COPY . .

# Expose the Flask port (Render maps this automatically)
EXPOSE 5000

# Start server using production gunicorn engine
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "api:app"]
