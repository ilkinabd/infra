import json
import os
import re
from urllib.parse import urlparse, urljoin
from flask import Flask, request, jsonify
from seleniumbase import SB
from bs4 import BeautifulSoup
from curl_cffi import requests as requests_cffi
from threading import Thread
from queue import Queue
import traceback

app = Flask(__name__)

# Global variables for browser worker
global_sb = None
global_sb_context = None
task_queue = Queue()

def init_browser():
    global global_sb, global_sb_context
    if global_sb_context:
        try:
            global_sb_context.__exit__(None, None, None)
        except Exception:
            pass
    
    print("Initializing global SeleniumBase instance...")
    proxy_env = os.environ.get('SCRAPER_PROXY')
    if proxy_env:
        print(f"Using configured proxy for SeleniumBase: {proxy_env}")
        global_sb_context = SB(uc=True, xvfb=True, locale_code="tr", proxy=proxy_env)
    else:
        global_sb_context = SB(uc=True, xvfb=True, locale_code="tr")
    global_sb = global_sb_context.__enter__()


    print("Global SeleniumBase instance initialized successfully.")



def scraper_worker():
    global global_sb
    try:
        init_browser()
    except Exception as e:
        print(f"Warning: Failed to initialize browser on startup: {str(e)}")
        
    while True:
        try:
            url, custom_shop_name, response_queue = task_queue.get()
            print(f"Worker thread processing: {url}")
            
            try:
                if global_sb is None:
                    init_browser()
                
                if os.environ.get('SCRAPER_PROXY'):
                    try:
                        print("Activating CDP mode for proxy authentication...")
                        global_sb.activate_cdp_mode(url)
                    except Exception as cdp_act_err:
                        print(f"Warning: Failed to activate CDP mode: {str(cdp_act_err)}")
                
                global_sb.uc_open_with_reconnect(url, 4)
                html_content = global_sb.get_page_source()
                page_title = global_sb.get_title()
                
                if is_block_title(page_title):
                    raise Exception(f"Failed to bypass Cloudflare protection. Title remains: {page_title}")
                    
                response_queue.put((html_content, page_title, None))
            except Exception as browser_err:
                print(f"Worker browser error: {str(browser_err)}. Re-initializing...")
                try:
                    init_browser()
                    if os.environ.get('SCRAPER_PROXY'):
                        try:
                            print("Activating CDP mode for proxy authentication on retry...")
                            global_sb.activate_cdp_mode(url)
                        except Exception as cdp_act_err:
                            print(f"Warning: Failed to activate CDP mode on retry: {str(cdp_act_err)}")
                            
                    global_sb.uc_open_with_reconnect(url, 4)
                    html_content = global_sb.get_page_source()
                    page_title = global_sb.get_title()
                    
                    if is_block_title(page_title):
                        raise Exception(f"Failed to bypass Cloudflare protection on retry. Title remains: {page_title}")
                        
                    response_queue.put((html_content, page_title, None))
                except Exception as retry_err:
                    response_queue.put((None, None, retry_err))


            finally:
                task_queue.task_done()
        except Exception as worker_err:
            print(f"Fatal worker error: {str(worker_err)}")


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
        
    print(f"🔍 Scraping: {url}")
    
    # 1. Katman: curl_cffi HTTP Request
    try:
        print("Layer 1: curl_cffi request...")
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
            "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
            "Referer": "https://www.google.com/",
        }
        cookies = {
            "storefrontId": "1",
            "countryCode": "TR",
            "language": "tr"
        }
        proxy_env = os.environ.get('SCRAPER_PROXY')
        proxies = None
        if proxy_env:
            proxies = {
                "http": f"http://{proxy_env}",
                "https": f"http://{proxy_env}"
            }
        res = requests_cffi.get(url, impersonate="chrome120", headers=headers, cookies=cookies, proxies=proxies, timeout=10)



        
        if res.status_code == 200:
            html_content = res.text
            soup = BeautifulSoup(html_content, 'html.parser')
            page_title = soup.title.string if soup.title else ""
            
            if not is_block_title(page_title):
                parsed = parse_metadata(html_content, url, default_title=page_title)
                if parsed and parsed.get('title'):
                    parsed['shopName'] = get_shop_name(url, custom_shop_name)
                    print(f"✅ Scraped successfully via Layer 1 (curl_cffi): {url}")
                    return jsonify(parsed)
            else:
                print(f"Layer 1 blocked by access denial or captcha page title. Title was: {page_title}")
        else:
            print(f"Layer 1 failed with status code: {res.status_code}")
            try:
                print(f"Layer 1 Response headers: {dict(res.headers)}")
                print(f"Layer 1 Response body (first 500 chars): {res.text[:500]}")
            except Exception:
                pass
            
    except Exception as e:
        print(f"Layer 1 failed with exception: {str(e)}")
        traceback.print_exc()

    # 2. Katman: SeleniumBase (Fallback)
    print("Layer 2: SeleniumBase fallback (routing through background worker thread)...")
    try:
        response_queue = Queue()
        task_queue.put((url, custom_shop_name, response_queue))
        
        html_content, page_title, err = response_queue.get(timeout=40)
        if err:
            raise err
            
        parsed = parse_metadata(html_content, url, default_title=page_title)
        parsed['shopName'] = get_shop_name(url, custom_shop_name)
        
        print(f"✅ Scraped successfully via Layer 2 (SeleniumBase): {url}")
        return jsonify(parsed)

    except Exception as e:
        print(f"❌ Layer 2 Error scraping {url}: {str(e)}")
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok', 'browser': True})

if __name__ == '__main__':
    # Start dedicated background worker thread
    worker_thread = Thread(target=scraper_worker, daemon=True)
    worker_thread.start()
        
    port = int(os.environ.get('PORT', 8085))
    app.run(host='0.0.0.0', port=port)


