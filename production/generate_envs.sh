#!/bin/bash
set -e

echo "⚙️ Creating production/front.env with correct API URL..."
cat > production/front.env <<EOF
LARAVEL_API_URL=https://api.lobbym.com/api
NEXT_PUBLIC_BASE_URL=https://lobbym.com
EOF

echo "⚙️ Flexibly generating api.env, admin.env, and report.env from templates..."

# 1. API
if [ -f "/var/www/dev.api.lobbym.com/deployments/.env" ]; then
    cp /var/www/dev.api.lobbym.com/deployments/.env production/api.env
elif [ -f "/var/www/dev.api.lobbym.com/.env" ]; then
    cp /var/www/dev.api.lobbym.com/.env production/api.env
elif [ -f "/var/www/dev.api.lobbym.com/.env.example" ]; then
    cp /var/www/dev.api.lobbym.com/.env.example production/api.env
fi

if [ -f "production/api.env" ]; then
    sed -i 's|APP_ENV=local|APP_ENV=production|g' production/api.env || true
    sed -i 's|APP_DEBUG=true|APP_DEBUG=false|g' production/api.env || true
    sed -i 's|APP_URL=.*|APP_URL=https://api.lobbym.com|g' production/api.env || true
    sed -i 's|APP_API_URL=.*|APP_API_URL=https://api.lobbym.com|g' production/api.env || true
    sed -i 's|APP_PUBLIC_URL=.*|APP_PUBLIC_URL=https://api.lobbym.com|g' production/api.env || true
    sed -i 's|APP_SOCKET_URL=.*|APP_SOCKET_URL=https://socket.lobbym.com|g' production/api.env || true
fi

# 2. Admin
if [ -f "/var/www/dev.admin.lobbym.com/deployments/.env" ]; then
    cp /var/www/dev.admin.lobbym.com/deployments/.env production/admin.env
elif [ -f "/var/www/dev.admin.lobbym.com/.env" ]; then
    cp /var/www/dev.admin.lobbym.com/.env production/admin.env
elif [ -f "/var/www/dev.admin.lobbym.com/.env.example" ]; then
    cp /var/www/dev.admin.lobbym.com/.env.example production/admin.env
fi

if [ -f "production/admin.env" ]; then
    sed -i 's|APP_ENV=local|APP_ENV=production|g' production/admin.env || true
    sed -i 's|APP_DEBUG=true|APP_DEBUG=false|g' production/admin.env || true
    sed -i 's|APP_URL=.*|APP_URL=https://admin.lobbym.com|g' production/admin.env || true
    sed -i 's|APP_API_URL=.*|APP_API_URL=https://api.lobbym.com|g' production/admin.env || true
    sed -i 's|APP_PUBLIC_URL=.*|APP_PUBLIC_URL=https://admin.lobbym.com|g' production/admin.env || true
    sed -i 's|APP_SOCKET_URL=.*|APP_SOCKET_URL=https://socket.lobbym.com|g' production/admin.env || true
fi

# 3. Report
if [ -f "/var/www/dev.report.lobbym.com/deployments/.env" ]; then
    cp /var/www/dev.report.lobbym.com/deployments/.env production/report.env
elif [ -f "/var/www/dev.report.lobbym.com/.env" ]; then
    cp /var/www/dev.report.lobbym.com/.env production/report.env
elif [ -f "/var/www/dev.report.lobbym.com/.env.example" ]; then
    cp /var/www/dev.report.lobbym.com/.env.example production/report.env
fi

if [ -f "production/report.env" ]; then
    sed -i 's|APP_ENV=local|APP_ENV=production|g' production/report.env || true
    sed -i 's|APP_DEBUG=true|APP_DEBUG=false|g' production/report.env || true
    sed -i 's|APP_URL=.*|APP_URL=https://report.lobbym.com|g' production/report.env || true
    sed -i 's|APP_API_URL=.*|APP_API_URL=https://api.lobbym.com|g' production/report.env || true
    sed -i 's|APP_PUBLIC_URL=.*|APP_PUBLIC_URL=https://report.lobbym.com|g' production/report.env || true
    sed -i 's|APP_SOCKET_URL=.*|APP_SOCKET_URL=https://socket.lobbym.com|g' production/report.env || true
fi

echo "🔗 Symlinking environment files to the repository roots on the host..."
ln -sf /root/dev.infra.lobbym.com/production/api.env /var/www/dev.api.lobbym.com/.env
ln -sf /root/dev.infra.lobbym.com/production/admin.env /var/www/dev.admin.lobbym.com/.env
ln -sf /root/dev.infra.lobbym.com/production/report.env /var/www/dev.report.lobbym.com/.env
ln -sf /root/dev.infra.lobbym.com/production/front.env /var/www/dev.lobbym.com/.env
