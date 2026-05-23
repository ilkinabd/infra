class AmazonParser {
    static get selectors() {
        return ['#productTitle', '#landingImage', '.a-price'];
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

        const pTitle = document.getElementById('productTitle');
        if (pTitle) title = pTitle.textContent.trim();
        
        const pImg = document.getElementById('landingImage') || document.querySelector('img.primary-image') || document.querySelector('[data-a-dynamic-image]');
        if (pImg) image = pImg.src || pImg.getAttribute('src');
        
        const pDesc = document.getElementById('productDescription');
        if (pDesc) desc = pDesc.textContent.trim();
        
        const pPrice = document.querySelector('.a-price .a-offscreen') || document.getElementById('price_inside_buybox') || document.querySelector('.a-price-whole');
        if (pPrice) price = pPrice.textContent.trim();

        if (image && !image.startsWith('http') && !image.startsWith('//')) {
            try {
                image = new URL(image, window.location.href).href;
            } catch (e) {}
        }

        return { title, image, desc, price };
    }
}

if (typeof window !== 'undefined') {
    window.AmazonParser = AmazonParser;
}

if (typeof module !== 'undefined' && module.exports) {
    module.exports = AmazonParser;
}
