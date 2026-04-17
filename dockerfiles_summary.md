# Dockerfiles Architecture

Here are the Dockerfiles currently defining your application's environments across your workspaces. As a Senior Developer, I've broken down what we have so far.

## 1. Frontend (`dev.front.lobbym.com`)
**Path:** `dev.front.lobbym.com/Dockerfile`

This container uses the latest Node LTS version and configures `pnpm` as the package manager via `corepack`. It's currently acting as a simple base container or command runner (`ENTRYPOINT ["pnpm"]`). 

```dockerfile
# Используем официальный образ Node (можно указать версию, например node:20-alpine)
FROM node:lts

# Устанавливаем pnpm через corepack (уже встроен в Node >=16.9)
RUN corepack enable && corepack prepare pnpm@latest --activate

# Рабочая директория внутри контейнера
WORKDIR /app

# По умолчанию просто открываем bash, можно заменить на pnpm
ENTRYPOINT ["pnpm"]
```

## 2. API Backend (`dev.api.lobbym.com`)
**Path:** `dev.api.lobbym.com/deployments/Dockerfile`

This is a very solid foundation for a modern Laravel backend. It uses PHP 8.3 FPM and installs the necessary extensions, importantly including `pdo_pgsql` (for Postgres) and `gd` with `webp` support for image manipulation. It also pulls in Composer 2.

```dockerfile
FROM php:8.3-fpm

RUN apt-get update && apt-get install -y \
    git unzip libzip-dev libpq-dev libpng-dev libjpeg-dev libonig-dev libxml2-dev curl \
    libwebp-dev libfreetype6-dev \
 && docker-php-ext-configure gd \
      --with-jpeg \
      --with-webp \
      --with-freetype \
 && docker-php-ext-install -j$(nproc) pdo pdo_pgsql mbstring zip exif pcntl bcmath gd

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

CMD ["php-fpm"]
```

## 3. Admin Backend (`dev.admin.lobbym.com`)
**Path:** `dev.admin.lobbym.com/deployments/Dockerfile`

This workspace is also a full Laravel application (likely running an admin panel like Filament or Nova). It completely mirrors the API configuration, which is great for consistency.

```dockerfile
FROM php:8.3-fpm

RUN apt-get update && apt-get install -y \
    git unzip libzip-dev libpq-dev libpng-dev libjpeg-dev libonig-dev libxml2-dev curl \
    libwebp-dev libfreetype6-dev \
 && docker-php-ext-configure gd \
      --with-jpeg \
      --with-webp \
      --with-freetype \
 && docker-php-ext-install -j$(nproc) pdo pdo_pgsql mbstring zip exif pcntl bcmath gd

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

CMD ["php-fpm"]
```

## Ecosystem Startup (`bash`)

To run the entire ecosystem (Frontend, API, Admin, and Infrastructure), I've designed a unified startup script. This handles network creation, dependency checking, and orchestrating `docker-compose`.

### 1. Unified Control Script (`run.sh`)
**Create this file in your root or `dev.infra.lobbym.com` directory.** This script automates the full stack initialization.

```bash
#!/bin/bash

# Configuration
NETWORK_NAME="lobbym-network"
INFRA_DIR="./dev.infra.lobbym.com"

echo "🚀 Starting Lobbym Ecosystem..."

# 1. Create shared network if it doesn't exist
if ! docker network ls | grep -q "$NETWORK_NAME"; then
  echo "🌐 Creating $NETWORK_NAME network..."
  docker network create "$NETWORK_NAME"
fi

# 2. Start Infrastructure (Postgres, Redis)
echo "📦 Starting Infrastructure (DB, Redis)..."
cd "$INFRA_DIR" && docker compose up -d

# 3. Optional: Add logic to start apps in dev mode
# (e.g., cd ../dev.front.lobbym.com && pnpm dev)

echo "✅ Ecosystem is pulsing."
```

### 2. Full-Stack Orchestration (`docker-compose.yml`)
As a senior dev, I recommend extending your `dev.infra.lobbym.com/docker-compose.yml` to include the app services. This allows you to manage everything with a single command.

```yaml
services:
  # Infrastructure
  db:
    image: postgres:17
    container_name: lobbym-postgres
    # ... (existing config)

  redis:
    image: redis:7-alpine
    container_name: lobbym-redis
    # ... (existing config)

  # Application Services
  api:
    build: 
      context: ../dev.api.lobbym.com
      dockerfile: deployments/Dockerfile
    container_name: lobbym-api
    volumes:
      - ../dev.api.lobbym.com:/var/www/html
    networks:
      - lobbym-network

  admin:
    build:
      context: ../dev.admin.lobbym.com
      dockerfile: deployments/Dockerfile
    container_name: lobbym-admin
    volumes:
      - ../dev.admin.lobbym.com:/var/www/html
    networks:
      - lobbym-network

  frontend:
    build:
      context: ../dev.front.lobbym.com
      dockerfile: Dockerfile
    container_name: lobbym-front
    volumes:
      - ../dev.front.lobbym.com:/app
    ports:
      - "3000:3000"
    networks:
      - lobbym-network

# ... (networks/volumes)
```

---

> [!TIP]
> **Pro Tip:** Register an alias in your `.zshrc` or `.bashrc`: 
> `alias lobbym-up='bash /path/to/dev.infra.lobbym.com/run.sh'` 

