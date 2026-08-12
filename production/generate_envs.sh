#!/bin/bash
set -e

# Ensure the enviroment folder exists
mkdir -p production/enviroment

# Helper function to copy template to production/enviroment
prepare_env() {
    local repo_dir=$1
    local dest_env=$2
    
    if [ -f "${repo_dir}/deployments/.env" ]; then
        echo "📋 Copying deployments/.env to $dest_env"
        cp "${repo_dir}/deployments/.env" "$dest_env"
    elif [ -f "${repo_dir}/.env" ] && [ ! -L "${repo_dir}/.env" ]; then
        echo "📋 Copying root .env to $dest_env"
        cp "${repo_dir}/.env" "$dest_env"
    elif [ -f "${repo_dir}/.env.example" ]; then
        echo "📋 Copying root .env.example to $dest_env"
        cp "${repo_dir}/.env.example" "$dest_env"
    fi
}

echo "⚙️ Generating environment files in production/enviroment..."

# 1. API
prepare_env "/var/www/dev.api.lobbym.com" "production/enviroment/api.env"
if [ -f "production/enviroment/api.env" ]; then
    sed -i 's|APP_ENV=local|APP_ENV=production|g' production/enviroment/api.env || true
    sed -i 's|APP_DEBUG=true|APP_DEBUG=false|g' production/enviroment/api.env || true
    sed -i 's|APP_URL=.*|APP_URL=https://api.lobbym.com|g' production/enviroment/api.env || true
    sed -i 's|APP_API_URL=.*|APP_API_URL=https://api.lobbym.com|g' production/enviroment/api.env || true
    sed -i 's|APP_PUBLIC_URL=.*|APP_PUBLIC_URL=https://api.lobbym.com|g' production/enviroment/api.env || true
    sed -i 's|APP_SOCKET_URL=.*|APP_SOCKET_URL=https://socket.lobbym.com|g' production/enviroment/api.env || true
    # Database
    sed -i 's|DB_CONNECTION=.*|DB_CONNECTION=pgsql|g' production/enviroment/api.env || true
    sed -i 's|DB_HOST=.*|DB_HOST=lobbym-postgres|g' production/enviroment/api.env || true
    sed -i 's|DB_PORT=.*|DB_PORT=5432|g' production/enviroment/api.env || true
    sed -i 's|DB_DATABASE=.*|DB_DATABASE=lobbym|g' production/enviroment/api.env || true
    sed -i 's|DB_USERNAME=.*|DB_USERNAME=postgres|g' production/enviroment/api.env || true
    sed -i 's|DB_PASSWORD=.*|DB_PASSWORD=postgres|g' production/enviroment/api.env || true
fi

# 2. Admin
prepare_env "/var/www/dev.admin.lobbym.com" "production/enviroment/admin.env"
if [ -f "production/enviroment/admin.env" ]; then
    sed -i 's|APP_ENV=local|APP_ENV=production|g' production/enviroment/admin.env || true
    sed -i 's|APP_DEBUG=true|APP_DEBUG=false|g' production/enviroment/admin.env || true
    sed -i 's|APP_URL=.*|APP_URL=https://admin.lobbym.com|g' production/enviroment/admin.env || true
    sed -i 's|APP_API_URL=.*|APP_API_URL=https://api.lobbym.com|g' production/enviroment/admin.env || true
    sed -i 's|APP_PUBLIC_URL=.*|APP_PUBLIC_URL=https://admin.lobbym.com|g' production/enviroment/admin.env || true
    sed -i 's|APP_SOCKET_URL=.*|APP_SOCKET_URL=https://socket.lobbym.com|g' production/enviroment/admin.env || true
    # Database
    sed -i 's|DB_CONNECTION=.*|DB_CONNECTION=pgsql|g' production/enviroment/admin.env || true
    sed -i 's|DB_HOST=.*|DB_HOST=lobbym-postgres|g' production/enviroment/admin.env || true
    sed -i 's|DB_PORT=.*|DB_PORT=5432|g' production/enviroment/admin.env || true
    sed -i 's|DB_DATABASE=.*|DB_DATABASE=lobbym|g' production/enviroment/admin.env || true
    sed -i 's|DB_USERNAME=.*|DB_USERNAME=postgres|g' production/enviroment/admin.env || true
    sed -i 's|DB_PASSWORD=.*|DB_PASSWORD=postgres|g' production/enviroment/admin.env || true
fi

# 3. Report
prepare_env "/var/www/dev.report.lobbym.com" "production/enviroment/report.env"
if [ -f "production/enviroment/report.env" ]; then
    sed -i 's|APP_ENV=local|APP_ENV=production|g' production/enviroment/report.env || true
    sed -i 's|APP_DEBUG=true|APP_DEBUG=false|g' production/enviroment/report.env || true
    sed -i 's|APP_URL=.*|APP_URL=https://report.lobbym.com|g' production/enviroment/report.env || true
    sed -i 's|APP_API_URL=.*|APP_API_URL=https://api.lobbym.com|g' production/enviroment/report.env || true
    sed -i 's|APP_PUBLIC_URL=.*|APP_PUBLIC_URL=https://report.lobbym.com|g' production/enviroment/report.env || true
    sed -i 's|APP_SOCKET_URL=.*|APP_SOCKET_URL=https://socket.lobbym.com|g' production/enviroment/report.env || true
    # Database
    sed -i 's|DB_CONNECTION=.*|DB_CONNECTION=pgsql|g' production/enviroment/report.env || true
    sed -i 's|DB_HOST=.*|DB_HOST=lobbym-postgres|g' production/enviroment/report.env || true
    sed -i 's|DB_PORT=.*|DB_PORT=5432|g' production/enviroment/report.env || true
    sed -i 's|DB_DATABASE=.*|DB_DATABASE=lobbym|g' production/enviroment/report.env || true
    sed -i 's|DB_USERNAME=.*|DB_USERNAME=postgres|g' production/enviroment/report.env || true
    sed -i 's|DB_PASSWORD=.*|DB_PASSWORD=postgres|g' production/enviroment/report.env || true
fi

# 4. Frontend
cat > "production/enviroment/front.env" <<EOF
LARAVEL_API_URL=https://api.lobbym.com/api
NEXT_PUBLIC_LARAVEL_URL=https://api.lobbym.com
NEXT_PUBLIC_BASE_URL=https://lobbym.com
NEXT_PUBLIC_SOCKET_URL=https://socket.lobbym.com
EOF

# Maintain legacy root copy path if other services reference it
cp production/enviroment/front.env production/front.env

# Clean up any leftover repository root .env files/symlinks on the host to keep code bases clean
rm -f /var/www/dev.api.lobbym.com/.env
rm -f /var/www/dev.admin.lobbym.com/.env
rm -f /var/www/dev.report.lobbym.com/.env
