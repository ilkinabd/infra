class HepsiburadaParser {
    static get selectors() {
        return [
            'script[type="application/ld+json"]',
            'h1[data-test-id="title"]',
            '[data-test-id="price"]'
        ];
    }

    static parse() {
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

        let title = null;
        let image = null;
        let desc = null;
        let price = null;

        // 1. Try window.utagData first
        if (window.utagData) {
            const utag = window.utagData;
            title = utag.product_name_array || (utag.product_names && utag.product_names[0]) || title;
            price = (utag.product_prices && utag.product_prices[0]) || 
                    (utag.product_unit_prices && utag.product_unit_prices[0]) || 
                    (utag.order_subtotal && utag.order_subtotal[0]) || price;
        }

        // 2. Try JSON-LD fallbacks
        title = title || extractFromJsonLd('name');
        image = image || extractFromJsonLd('image');
        desc = desc || extractFromJsonLd('description');
        price = price || extractFromJsonLd('price');

        // 3. DOM element fallbacks
        if (!title) {
            const h1El = document.querySelector('h1[data-test-id="title"]') || document.querySelector('h1');
            if (h1El) title = h1El.textContent.trim();
        }

        if (!price) {
            const prEl = document.querySelector('[data-test-id="price"]') || 
                         document.querySelector('[data-test-id="default-price"]') ||
                         document.querySelector('[itemprop="price"]');
            if (prEl) price = prEl.textContent.trim() || prEl.getAttribute('content');
        }

        if (!image) {
            const imgEl = document.querySelector('img.hb-HbImage-view__image') || 
                          document.querySelector('img[class*="hb-HbImage-view"]') ||
                          document.querySelector('link[rel="preload"][as="image"]');
            if (imgEl) image = imgEl.src || imgEl.getAttribute('href');
        }

        // Final fallbacks / cleanups
        title = title || document.title;

        if (image && !image.startsWith('http') && !image.startsWith('//')) {
            try {
                image = new URL(image, window.location.href).href;
            } catch (e) {}
        }

        return { title, image, desc, price };
    }
}

if (typeof window !== 'undefined') {
    window.HepsiburadaParser = HepsiburadaParser;
}

if (typeof module !== 'undefined' && module.exports) {
    module.exports = HepsiburadaParser;
}
