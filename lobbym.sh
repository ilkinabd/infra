#!/bin/bash
set -e

# Error handling function
error_exit() {
  echo "❌ Error on line $1 of lobbym.sh. Ecosystem startup failed."
  exit 1
}
trap 'error_exit $LINENO' ERR

# Configuration
MODE=${1:-prod}
NETWORK_NAME="lobbym-network"
ROOT_DIR="/home/iandr"
INFRA_DIR="$ROOT_DIR/dev.infra.lobbym.com"


API_DIR="$ROOT_DIR/dev.api.lobbym.com"
ADMIN_DIR="$ROOT_DIR/dev.admin.lobbym.com"
FRONT_DIR="$ROOT_DIR/dev.front.lobbym.com"

echo "🎯 Mode: $MODE"
if [ "$MODE" = "dev" ]; then
  echo "🛠️  DEVELOPMENT MODE ENABLED"
fi

# Verify directories exist
for dir in "$INFRA_DIR" "$API_DIR" "$ADMIN_DIR" "$FRONT_DIR"; do
  if [ ! -d "$dir" ]; then
    echo "🚨 ERROR: Directory NOT FOUND: $dir"
    exit 1
  fi
done

# Helper for Dockerized NPM
docker_npm() {
  echo "🐳 Running NPM in Docker: npm $*"
  docker run --rm \
    -v "$(pwd):/app" \
    -w /app \
    -u "$(id -u):$(id -g)" \
    node:20-alpine \
    npm "$@"
}

# Helper for Dockerized PNPM
docker_pnpm() {
  echo "🐳 Running PNPM in Docker: pnpm $*"
  docker run --rm \
    -v "$(pwd):/app" \
    -w /app \
    -u "$(id -u):$(id -g)" \
    -e COREPACK_ENABLE_AUTO_CONFIRM=1 \
    -e COREPACK_HOME=/tmp/corepack \
    node:20-alpine \
    corepack pnpm "$@"
}

echo "🚀 Starting Lobbym Ecosystem..."

# Helper for Dockerized Composer
docker_composer() {
  echo "🐳 Running Composer in Docker: composer $*"
  docker run --rm \
    -v "$(pwd):/app" \
    -w /app \
    -u "$(id -u):$(id -g)" \
    composer:2.6 \
    composer "$@" --ignore-platform-reqs
}

# 1. Create shared network if it doesn't exist
if ! docker network ls | grep -q "$NETWORK_NAME"; then
  echo "🌐 Creating $NETWORK_NAME network..."
  docker network create "$NETWORK_NAME"
fi

# 2. Start Infrastructure (Postgres, Redis)
echo "📦 Starting Infrastructure (DB, Redis)..."
cd "$INFRA_DIR" && docker compose up -d


# 3. Start Backend Services
echo "🐘 Starting API Backend..."
cd "$API_DIR"
docker_composer install
cd "$API_DIR/deployments" && docker compose up -d --build

echo "📊 Starting Admin Backend..."
cd "$ADMIN_DIR"
docker_composer install
if [ ! -d "node_modules" ]; then docker_npm install; fi
# Build only if resources folder exists
if [ -d "resources" ]; then docker_npm run build; else echo "⏩ Skipping Admin build (no resources folder found)"; fi
cd "$ADMIN_DIR/deployments" && docker compose up -d --build

echo "⚛️ Starting Frontend..."
cd "$FRONT_DIR"
if [ ! -d "node_modules" ]; then docker_pnpm install; fi
# Build only if app source directory exists and NOT in dev mode
if [ "$MODE" != "dev" ]; then
  if [ -d "app" ] || [ -d "src" ]; then docker_pnpm run build; else echo "⏩ Skipping Frontend build (no source folder found)"; fi
  cd "$FRONT_DIR/deployments" && docker compose up -d
else
  # Development mode: skip build and start dev server
  echo "🚀 Starting Frontend in development mode (pnpm dev)..."
  cd "$FRONT_DIR/deployments"
  docker rm -f lobbym-front || true
  docker compose run -d --name lobbym-front --service-ports lobbym-front dev
fi

# Wait for containers to be ready
echo "⏳ Waiting for containers to stabilize..."
sleep 2

echo "🔓 Fixing folder permissions..."
docker exec lobbym-api-php chmod -R 777 storage bootstrap/cache || true
docker exec lobbym-admin-php chmod -R 777 storage bootstrap/cache || true

# 4. Run Migrations and Seeding
echo "🛠️  Running Admin Migrations & Seeding..."
docker exec lobbym-admin-php php artisan migrate:fresh --seed

echo "✅ Ecosystem is pulsing, databases are fresh, and users are created."
echo "-------------------------------------------------------------------"

echo "📋 Current Users Summary:"
echo "--- API Users ---"
docker exec lobbym-api-php php artisan tinker --execute="foreach(App\User::all(['name', 'mail']) as \$u) { echo \$u->name . ' (' . \$u->mail . ')' . PHP_EOL; }"
echo "--- Admin Users ---"
docker exec lobbym-admin-php php artisan tinker --execute="foreach(DB::table('panel_users')->get() as \$u) { echo \$u->name . ' (' . \$u->user_name . ')' . PHP_EOL; }"

echo "-------------------------------------------------------------------"
echo "API Admin: magaza@example.com / 12345"
echo "Panel Admin: admin / 12345"
echo "Admin Panel: http://localhost:8081"
echo "Frontend: http://localhost:3000"
echo "-------------------------------------------------------------------"
