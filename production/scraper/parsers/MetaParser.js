class MetaParser {
    static get selectors() {
        return [
            'meta[property="og:title"]',
            'meta[name="twitter:title"]',
            'meta[property="og:image"]',
            'meta[name="twitter:image"]',
            'meta[name="description"]',
            'meta[property="og:description"]',
            'meta[itemprop="price"]',
            'script[type="application/ld+json"]'
        ];
    }

    static parse() {
        const getMeta = (nameOrProp) => {
            let el = document.querySelector(`meta[property="${nameOrProp}"]`);
            if (!el) el = document.querySelector(`meta[name="${nameOrProp}"]`);
            return el ? el.getAttribute('content') : null;
        };

        const findInObj = (obj, targetKey) => {
            if (!obj || typeof obj !== 'object') return null;

            if (obj[targetKey] !== undefined) {
                const val = obj[targetKey];
                if (typeof val === 'string' || typeof val === 'number') {
                    return String(val);
                }
                if (Array.isArray(val)) {
                    const first = val[0];
                    if (typeof first === 'string') return first;
                    if (first && first.url) return first.url;
                }
                if (val && typeof val === 'object') {
                    return val.url || 
                           (val.value !== undefined ? String(val.value) : null) || 
                           (val.price !== undefined ? String(val.price) : null);
                }
            }

            for (const key in obj) {
                if (Object.prototype.hasOwnProperty.call(obj, key)) {
                    const res = findInObj(obj[key], targetKey);
                    if (res) return res;
                }
            }
            return null;
        };

        const extractFromJsonLd = (property) => {
            const scripts = document.querySelectorAll('script[type="application/ld+json"]');
            for (const script of scripts) {
                try {
                    const json = JSON.parse(script.textContent.trim());
                    const found = findInObj(json, property);
                    if (found) return found;
                } catch (e) {}
            }
            return null;
        };

        const isBlockTitle = (t) => {
            if (!t) return false;
            const btList = ['access denied', 'pardon our interruption', 'attention required', 'security check', 'checking your browser', 'güvenlik', 'robot check', 'interruption', 'just a moment'];
            const lower = t.toLowerCase();
            return btList.some(bt => lower.includes(bt));
        };

        let title = getMeta('og:title') || getMeta('twitter:title') || document.title;
        let image = getMeta('og:image') || getMeta('twitter:image');
        let desc = getMeta('og:description') || getMeta('description');
        let price = getMeta('product:price:amount') || getMeta('og:price:amount') || getMeta('price');

        if (isBlockTitle(title)) {
            title = null;
        }

        // Generic JSON-LD fallback for all pages if fields still missing
        if (!title || isBlockTitle(title)) {
            title = extractFromJsonLd('name') || title;
        }
        if (!image) {
            image = extractFromJsonLd('image') || image;
        }
        if (!desc) {
            desc = extractFromJsonLd('description') || desc;
        }
        if (!price) {
            price = extractFromJsonLd('price') || document.querySelector('[itemprop="price"]')?.getAttribute('content') || price;
        }

        // Final fallbacks
        if (!image) {
            const mainImg = document.querySelector('img[itemprop="image"]') || document.querySelector('link[rel="image_src"]');
            if (mainImg) image = mainImg.src || mainImg.getAttribute('href');
        }

        if (image && !image.startsWith('http') && !image.startsWith('//')) {
            try {
                image = new URL(image, window.location.href).href;
            } catch (e) {}
        }

        return { title, image, desc, price };
    }
}

if (typeof window !== 'undefined') {
    window.MetaParser = MetaParser;
}

if (typeof module !== 'undefined' && module.exports) {
    module.exports = MetaParser;
}
