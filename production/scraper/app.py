import json
import os
import re
from urllib.parse import urlparse, urljoin
from flask import Flask, request, jsonify
from seleniumbase import SB
from bs4 import BeautifulSoup

app = Flask(__name__)

def find_in_obj(obj, target_key):
    if not obj:
        return None
    
    if isinstance(obj, dict):
        if target_key in obj:
            val = obj[target_key]
            if isinstance(val, (str, int, float)):
                return str(val)
            if isinstance(val, list) and val:
                first = val[0]
                if isinstance(first, str):
                    return first
                if isinstance(first, dict) and 'url' in first:
                    return first['url']
            if isinstance(val, dict):
                if 'url' in val:
                    return val['url']
                if 'value' in val:
                    return str(val['value'])
                if 'price' in val:
                    return str(val['price'])
        
        for key, value in obj.items():
            res = find_in_obj(value, target_key)
            if res is not None:
                return res
                
    elif isinstance(obj, list):
        for item in obj:
            res = find_in_obj(item, target_key)
            if res is not None:
                return res
                
    return None

def extract_from_json_ld(soup, property_name):
    scripts = soup.find_all('script', type='application/ld+json')
    for script in scripts:
        try:
            content = script.string
            if not content:
                continue
            data = json.loads(content.strip())
            found = find_in_obj(data, property_name)
            if found:
                return found
        except Exception:
            pass
    return None

def clean_str(s):
    if isinstance(s, str):
        return re.sub(r'\s+', ' ', s).strip()
    return s

def is_block_title(t):
    if not t:
        return False
    bt_list = ['access denied', 'pardon our interruption', 'attention required', 'security check', 'checking your browser', 'güvenlik', 'robot check', 'interruption', 'just a moment']
    lower = t.lower()
    return any(bt in lower for bt in bt_list)

def parse_metadata(html_content, page_url, default_title=""):
    soup = BeautifulSoup(html_content, 'html.parser')
    
    def get_meta(name_or_prop):
        el = soup.find('meta', property=name_or_prop)
        if not el:
            el = soup.find('meta', attrs={'name': name_or_prop})
        return el.get('content') if el else None

    # Title extraction
    title = get_meta('og:title') or get_meta('twitter:title') or (soup.title.string if soup.title else None) or default_title
    title = clean_str(title)
    if is_block_title(title):
        title = None

    # Image extraction
    image = get_meta('og:image') or get_meta('og:image:secure_url') or get_meta('twitter:image')
    
    # Description extraction
    desc = get_meta('og:description') or get_meta('description') or get_meta('twitter:description')
    
    # Price extraction
    price = get_meta('product:price:amount') or get_meta('og:price:amount') or get_meta('price')

    # Currency extraction
    currency = get_meta('product:price:currency') or get_meta('og:price:currency') or get_meta('priceCurrency')

    # Fallbacks via JSON-LD
    if not title or is_block_title(title):
        title = clean_str(extract_from_json_ld(soup, 'name')) or title
        
    if not image:
        image = extract_from_json_ld(soup, 'image')
        
    if not desc:
        desc = clean_str(extract_from_json_ld(soup, 'description'))
        
    if not price:
        price = extract_from_json_ld(soup, 'price')
        if not price:
            itemprop_price = soup.find(attrs={'itemprop': 'price'})
            if itemprop_price:
                price = itemprop_price.get('content') or itemprop_price.text

    if not currency:
        currency = extract_from_json_ld(soup, 'priceCurrency')
        if not currency:
            itemprop_currency = soup.find(attrs={'itemprop': 'priceCurrency'})
            if itemprop_currency:
                currency = itemprop_currency.get('content') or itemprop_currency.text

    # Final Image Fallbacks
    if not image:
        main_img = soup.find('img', itemprop='image')
        if main_img:
            image = main_img.get('src')
        if not image:
            link_img = soup.find('link', rel='image_src')
            if link_img:
                image = link_img.get('href')

    if image:
        image = clean_str(image)
        if not image.startswith('http') and not image.startswith('//'):
            try:
                image = urljoin(page_url, image)
            except Exception:
                pass

    # Trim price and currency separately
    formatted_price = clean_str(price)
    clean_curr = clean_str(currency) if currency else ""

    if formatted_price:
        # If currency is not explicitly provided, try to extract it from the price string
        if not clean_curr:
            match = re.search(r'(?i)\b(TL|TRY|USD|EUR|GBP)\b|[\$\€\£\₺]', formatted_price)
            if match:
                clean_curr = match.group(0)
        
        # Strip currency code/symbol from price
        if clean_curr:
            formatted_price = re.sub(re.escape(clean_curr), '', formatted_price, flags=re.IGNORECASE)
        
        # Clean any remaining common symbols/words from price
        formatted_price = re.sub(r'(?i)\b(TL|TRY|USD|EUR|GBP)\b', '', formatted_price)
        formatted_price = re.sub(r'[\$\€\£\₺]', '', formatted_price)
        formatted_price = formatted_price.strip()
        formatted_price = re.sub(r'^[\s\-–—/]+|[\s\-–—/]+$', '', formatted_price)

    return {
        'title': title,
        'image': image,
        'desc': clean_str(desc),
        'price': formatted_price,
        'currency': clean_curr
    }

def get_shop_name(url, custom_shop_name=None):
    if custom_shop_name:
        return custom_shop_name
    try:
        parsed = urlparse(url)
        hostname = parsed.netloc.lower()
        host_clean = hostname.replace('www.', '')
        parts = host_clean.split('.')
        if len(parts) >= 2:
            name = parts[-2]
            return name.capitalize()
        else:
            return host_clean.capitalize()
    except Exception:
        return 'İnternet Mağazası'

@app.route('/scrape', methods=['POST'])
def scrape():
    data = request.get_json() or {}
    url = data.get('url')
    custom_shop_name = data.get('shopName')
    
    if not url:
        return jsonify({'error': 'url parameter is required'}), 400
        
    print(f"🔍 Scraping: ${url}")
    
    try:
        # Use SB context manager with undetected-chromedriver (uc=True)
        # and Xvfb virtual display (xvfb=True) for stealth headless mode in Docker
        with SB(uc=True, xvfb=True) as sb:
            print("Opening google.com first for referer/cookie establishment...")
            sb.uc_open_with_reconnect("https://www.google.com", 4)
            sb.sleep(2)
            
            print("Opening target URL in undetected mode...")
            sb.uc_open_with_reconnect(url, 4)
            
            # Fetch page content
            html_content = sb.get_page_source()
            page_title = sb.get_title()
            
            # Parse page content using python parser
            parsed = parse_metadata(html_content, url, default_title=page_title)
            parsed['shopName'] = get_shop_name(url, custom_shop_name)
            
            print(f"✅ Scraped successfully: {url}")
            return jsonify(parsed)
            
    except Exception as e:
        print(f"❌ Error scraping {url}: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok', 'browser': True})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8085))
    app.run(host='0.0.0.0', port=port)
