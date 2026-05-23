class TrendyolParser {
    static get selectors() {
        return ['#pdp-page-layout'];
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

        if (window.__envoy__SHARED_PROPS && window.__envoy__SHARED_PROPS.product) {
            const prod = window.__envoy__SHARED_PROPS.product;
            if (!title || isBlockTitle(title)) {
                title = prod.name || title;
            }
            if (!image) {
                image = prod.images && prod.images.length > 0 ? prod.images[0] : image;
            }
            if (!price) {
                if (prod.winnerVariant && prod.winnerVariant.price) {
                    const pObj = prod.winnerVariant.price;
                    price = (pObj.discountedPrice && pObj.discountedPrice.value) || 
                            (pObj.sellingPrice && pObj.sellingPrice.value) || 
                            (pObj.originalPrice && pObj.originalPrice.value) || price;
                }
            }
        }

        // Fallbacks from DOM
        if (!title || isBlockTitle(title)) {
            const h1 = document.querySelector('h1.pr-new-br') || document.querySelector('.pr-new-br');
            if (h1) title = h1.textContent.trim();
        }
        if (!image) {
            const img = document.querySelector('.product-slide img') || document.querySelector('.gallery-container img');
            if (img) image = img.src;
        }
        if (!price) {
            const prEl = document.querySelector('.prc-dsc') || 
                         document.querySelector('.prc-slg') ||
                         document.querySelector('.ty-plus-price-original-price');
            if (prEl) price = prEl.textContent.trim();
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
    window.TrendyolParser = TrendyolParser;
}

if (typeof module !== 'undefined' && module.exports) {
    module.exports = TrendyolParser;
}
