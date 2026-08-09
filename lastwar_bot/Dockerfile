FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        adb tesseract-ocr \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY lastwar_bot ./lastwar_bot

CMD ["python", "-m", "lastwar_bot"]
