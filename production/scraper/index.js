const express = require('express');
const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
puppeteer.use(StealthPlugin());

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 8085;
let browser = null;

async function initBrowser() {
    try {
        console.log('🚀 Launching Puppeteer browser...');
        browser = await puppeteer.launch({
            headless: 'new',
            args: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-accelerated-2d-canvas',
                '--no-first-run',
                '--no-zygote',
                '--disable-gpu',
                '--single-process',
                '--disable-blink-features=AutomationControlled'
            ]
        });
        console.log('✅ Browser launched successfully.');
    } catch (err) {
        console.error('❌ Failed to launch browser:', err);
        process.exit(1);
    }
}

app.post('/scrape', async (req, res) => {
    const { url } = req.body;
    if (!url) {
        return res.status(400).json({ error: 'url parameter is required' });
    }

    console.log(`🔍 Scraping: ${url}`);
    let page = null;

    try {
        page = await browser.newPage();


        // Use standard screen viewport
        await page.setViewport({ width: 1920, height: 1080 });

        // Navigate to the URL with robust waiting to avoid navigation errors
        await page.goto(url, {
            waitUntil: 'networkidle0', // wait until 0 network connections for 500ms (strictest)
            timeout: 60000 // 60s timeout for slow pages
        });

        // Ensure the page's JS has fully executed and the DOM is ready
        await page.waitForFunction('document.readyState === "complete"');

        // Scroll down the page to trigger lazy-loaded content
        await page.evaluate(async () => {
            await new Promise((resolve) => {
                let totalHeight = 0;
                const distance = 300;
                const timer = setInterval(() => {
                    window.scrollBy(0, distance);
                    totalHeight += distance;
                    if (totalHeight >= document.body.scrollHeight) {
                        clearInterval(timer);
                        window.scrollTo(0, 0); // scroll back to top
                        resolve();
                    }
                }, 100);
            });
        });

        // Wait for lazy-loaded content to render after scroll
        await new Promise(resolve => setTimeout(resolve, 5000));

        // Get final HTML content
        const html = await page.content();
        
        console.log(`✅ Scraped successfully: ${url} (length: ${html.length})`);
        return res.json({ html });

    } catch (err) {
        console.error(`❌ Error scraping ${url}:`, err.message);
        return res.status(500).json({ error: err.message });
    } finally {
        if (page) {
            try {
                await page.close();
            } catch (closeErr) {
                console.error('Error closing page:', closeErr.message);
            }
        }
    }
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ status: 'ok', browser: browser !== null });
});

// Initialize browser and start server
initBrowser().then(() => {
    app.listen(PORT, '0.0.0.0', () => {
        console.log(`📶 Scraper service listening on port ${PORT}`);
    });
});
