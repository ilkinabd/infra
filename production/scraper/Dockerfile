FROM ghcr.io/puppeteer/puppeteer:22.6.0

USER pptruser
WORKDIR /home/pptruser/app

# Copy package configuration with correct ownership
COPY --chown=pptruser:pptruser package.json ./

# Install dependencies (puppeteer package will skip downloading Chromium since it's already installed in the image)
RUN npm install

# Copy application script and parsers
COPY --chown=pptruser:pptruser index.js ./
COPY --chown=pptruser:pptruser parsers/ ./parsers/

EXPOSE 8085

CMD ["node", "index.js"]
