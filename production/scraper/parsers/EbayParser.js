class EbayParser {
    static get selectors() {
        return ['.x-price-primary', '#prcIsum', '.display-price'];
    }

    static parse() {
        const getMeta = (nameOrProp) => {
            let el = document.querySelector(`meta[property="${nameOrProp}"]`);
            if (!el) el = document.querySelector(`meta[name="${nameOrProp}"]`);
            return el ? el.getAttribute('content') : null;
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

        const pPrice = document.querySelector('.x-price-primary') || document.getElementById('prcIsum') || document.querySelector('.display-price') || document.querySelector('[itemprop="price"]');
        if (pPrice) price = pPrice.textContent || pPrice.getAttribute('content') || price;

        if (image && !image.startsWith('http') && !image.startsWith('//')) {
            try {
                image = new URL(image, window.location.href).href;
            } catch (e) {}
        }

        return { title, image, desc, price };
    }
}

if (typeof window !== 'undefined') {
    window.EbayParser = EbayParser;
}

if (typeof module !== 'undefined' && module.exports) {
    module.exports = EbayParser;
}
