const express = require('express');
const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
const fs = require('fs');
const path = require('path');
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
    const { url, shopName: customShopName } = req.body;
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

        let parserFile = 'MetaParser.js';
        let parserClass = 'MetaParser';

        // Dynamically require the parser to retrieve its selectors
        const Parser = require(path.join(__dirname, 'parsers', parserFile));
        const selectors = Parser.selectors || [];

        if (selectors.length > 0) {
            try {
                await page.waitForFunction((selList) => {
                    return selList.some(sel => !!document.querySelector(sel));
                }, { timeout: 10000 }, selectors);
                console.log(`✅ Found expected selectors for ${parserClass}.`);
            } catch (err) {
                console.warn(`⚠️ Warning: Timed out waiting for selectors:`, err.message);
            }
        }

        // Inject the selected parser script onto the page
        const parserContent = fs.readFileSync(path.join(__dirname, 'parsers', parserFile), 'utf8');
        await page.evaluate(parserContent);

        // Evaluate extraction in page context
        const extractedData = await page.evaluate((parserClass, customShopName) => {
            const parser = window[parserClass];
            if (!parser) {
                throw new Error(`Parser ${parserClass} not found on the window object`);
            }

            const res = parser.parse();

            // Determine shopName
            let shopName = 'İnternet Mağazası';
            if (customShopName) {
                shopName = customShopName;
            } else {
                const hostname = window.location.hostname.toLowerCase();
                const hostClean = hostname.replace('www.', '');
                const parts = hostClean.split('.');
                if (parts.length >= 2) {
                    const name = parts[parts.length - 2];
                    shopName = name.charAt(0).toUpperCase() + name.slice(1);
                } else {
                    shopName = hostClean.charAt(0).toUpperCase() + hostClean.slice(1);
                }
            }

            const cleanStr = (s) => typeof s === 'string' ? s.replace(/\s+/g, ' ').trim() : s;

            return {
                title: cleanStr(res.title) || null,
                image: cleanStr(res.image) || null,
                desc: cleanStr(res.desc) || null,
                price: cleanStr(res.price) || null,
                shopName: shopName
            };
        }, parserClass, customShopName);

        console.log(`✅ Scraped successfully: ${url}`);
        return res.json({
            title: extractedData.title,
            image: extractedData.image,
            desc: extractedData.desc,
            price: extractedData.price,
            shopName: extractedData.shopName
        });

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
