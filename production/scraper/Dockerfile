FROM python:3.11-slim

# Install system dependencies, Xvfb, Chrome and Chromedriver dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    unzip \
    xvfb \
    libxi6 \
    libnss3 \
    libxss1 \
    libasound2 \
    libatk-bridge2.0-0 \
    libgtk-3-0 \
    libgbm1 \
    fonts-liberation \
    xdg-utils \
    python3-tk \
    && rm -rf /var/lib/apt/lists/*

# Install Google Chrome stable
RUN curl -sSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o chrome.deb \
    && apt-get update && apt-get install -y ./chrome.deb \
    && rm chrome.deb

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Pre-install ChromeDriver matching the installed Chrome version
RUN seleniumbase install chromedriver

COPY app.py ./

EXPOSE 8085

CMD ["python", "app.py"]
