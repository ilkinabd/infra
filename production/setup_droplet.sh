#!/bin/bash
set -e

MODE=${1:-"prod"}
echo "🚀 Starting Setup for Lobbym Infra ($MODE mode)..."

# 1. Update and Install Dependencies
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release openssl

# 2. Install Docker
if ! [ -x "$(command -v docker)" ]; then
    echo "📦 Installing Docker..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

# 3. Setup Directories
mkdir -p mailu/data mailu/config mailu/dkim mailu/mail mailu/overrides mailu/filter mailu/webmail mailu/certs
mkdir -p scraper
echo "📂 Directories ready."

# 4. Handle TLS Configuration based on mode
if [ "$MODE" == "local" ]; then
    TLS_FLAVOR="cert"
    HOSTNAMES="mail.lobbym.com,lobbym.com,localhost,127.0.0.1"
    if [ ! -f "mailu/certs/cert.pem" ]; then
        echo "🔐 Generating Multi-Name Self-Signed Certificate..."
        openssl req -x509 -newkey rsa:4096 \
          -keyout mailu/certs/key.pem -out mailu/certs/cert.pem \
          -sha256 -days 3650 -nodes \
          -subj "/CN=lobbym.com" \
          -addext "subjectAltName = DNS:lobbym.com, DNS:mail.lobbym.com, DNS:localhost, IP:127.0.0.1"
    fi
else
    TLS_FLAVOR="letsencrypt"
    # Note: Only using mail subdomain for HOSTNAMES to avoid Cloudflare Proxy issues with root domain during LE validation
    HOSTNAMES="mail.lobbym.com"
fi

# 5. Handle Configuration
if [ ! -f "mailu.env" ] || [ ! -z "$1" ]; then
    echo "⚙️  Configuring mailu.env for $MODE mode..."
    cat > mailu.env <<EOF
DEBUG=false
BYPASS_DNS_CHECK=true
DNS_RESOLVER=172.22.0.254
DOMAIN=lobbym.com
HOSTNAMES=$HOSTNAMES
POSTMASTER=admin
SECRET_KEY=$(openssl rand -base64 32)
MESSAGE_SIZE_LIMIT=50000000
SESSION_TIMEOUT=3600
AUTH_DRIVER=internal
TLS_FLAVOR=$TLS_FLAVOR
DB_FLAVOR=sqlite
WEBMAIL=snappymail
ADMIN=true
WEBROOT=/
WEB_ADMIN=/admin
WEB_WEBMAIL=/webmail
WEB_STATIC=/static
SITENAME=Lobbym Mail
WEBSITE=https://lobbym.com
ANTISPAM=rspamd
ANTIVIRUS=none
SCAN_MACROS=true
SERVICES=imap,smtp,pop3,antispam,webmail,admin,front
SUBNET=172.22.0.0/16
EOF
fi

# 6. Bring up services
echo "🐳 Starting Containers..."
sudo docker compose up --build -d

echo "✅ Deployment Successful!"
echo "--------------------------------------------------"
echo "Mode:     $MODE ($TLS_FLAVOR)"
echo "Admin UI: https://[YOUR_IP]/admin"
echo "Webmail:  https://[YOUR_IP]/webmail"
echo "Database: [YOUR_IP]:5433"
echo "Scraper:  [YOUR_IP]:8085 (internal)"
echo "--------------------------------------------------"
