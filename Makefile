ROOT_DIR = /home/iandr
API_DIR = $(ROOT_DIR)/dev.api.lobbym.com
ADMIN_DIR = $(ROOT_DIR)/dev.admin.lobbym.com
FRONT_DIR = $(ROOT_DIR)/dev.front.lobbym.com
REPORT_DIR = $(ROOT_DIR)/dev.report.lobbym.com

# Load root environment configuration if it exists
ifneq (,$(wildcard .env))
    include .env
    export
endif
DOCKER_UID_GID = -u "$$(id -u):$$(id -g)"
MODE ?= prod

# Helper functions for containerized tool runners
define run_composer
	docker run --rm -v "$(1):/app" -w /app $(DOCKER_UID_GID) composer:2.6 composer $(2) --ignore-platform-reqs
endef

define run_npm
	docker run --rm -v "$(1):/app" -w /app $(DOCKER_UID_GID) node:22-alpine npm $(2)
endef

define run_pnpm
	docker run --rm -v "$(1):/app" -w /app $(DOCKER_UID_GID) -e COREPACK_ENABLE_AUTO_CONFIRM=1 -e COREPACK_HOME=/tmp/corepack node:22-alpine corepack pnpm $(2)
endef

.PHONY: help local local-clean local-front-build local-front-dev local-db-seed local-search-reindex local-logs-clear hosts-add hosts-remove \
        prod-install-deps prod-app-start prod-app-stop prod-app-restart \
        prod-mail-start prod-mail-stop prod-mail-restart prod-status prod-logs \
        prod-mail-user-add prod-mail-user-del prod-mail-user-pass prod-mail-admin-add \
        prod-mail-domain-add prod-mail-domain-del prod-mail-restart \
        prod-db-create prod-db-drop prod-db-user-add prod-db-user-pass prod-db-user-del prod-db-list prod-db-reset prod-storage-link \
        prod-scraper-restart prod-scraper-rebuild prod-cassandra-cqlsh prod-cassandra-restart \
        prod-rabbitmq-restart prod-elastic-restart prod-search-reindex \
        prod-infra-start prod-infra-stop prod-backend-start prod-backend-stop prod-front-start prod-front-stop

help:
	@echo "Lobbym Infrastructure Management Console"
	@echo "========================================="
	@echo "Local Environment Commands:"
	@echo "  make local            - Build and start the entire local development ecosystem"
	@echo "  make local-clean      - Stop and clean local docker compose containers and volumes"
	@echo "  make local-front-build - Rebuild Next.js frontend and restart frontend container"
	@echo "  make local-db-seed    - Run database migrations and seeders for local environment"
	@echo "  make local-search-reindex - Recreate and populate Elasticsearch search indexes"
	@echo "  make local-logs-clear - Empty the mail_worker.log file"
	@echo "  make hosts-add        - Add dev domains to Windows hosts file"
	@echo "  make hosts-remove     - Remove dev domains from Windows hosts file"
	@echo ""
	@echo "Production (Droplet) Commands:"
	@echo "  make prod-install-deps    - Install system ca-certs, openssl, and docker-ce on VPS"
	@echo "  make prod-repos-pull      - Clone or pull latest updates from Bitbucket repositories"
	@echo "  make prod-env-init        - Initialize root .env file from .env.example"
	@echo "  make prod-env-generate    - Parse environment variables and generate service configurations"
	@echo "  make prod-env-clean       - Delete all generated environment and config files"
	@echo "  make prod-app-start       - Start main Lobbym application stack on droplet"
	@echo "  make prod-app-stop        - Stop main Lobbym application stack on droplet"
	@echo "  make prod-app-restart     - Restart main Lobbym application stack on droplet"
	@echo "  make prod-infra-start     - Start backend infrastructure (db, redis, cassandra, rabbitmq, nginx, kibana, elasticsearch)"
	@echo "  make prod-infra-stop      - Stop backend infrastructure"
	@echo "  make prod-backend-start   - Build and start backend services (api, admin, report, scraper, socket)"
	@echo "  make prod-backend-stop    - Stop backend services"
	@echo "  make prod-front-start     - Build and start frontend service (lobbym-front)"
	@echo "  make prod-front-stop      - Stop frontend service"
	@echo "  make prod-nginx-restart   - Restart Nginx proxy container on droplet"
	@echo "  make prod-front-build     - Rebuild Next.js frontend and restart frontend container"
	@echo "  make prod-db-migrate      - Run production Laravel database migrations safely"
	@echo "  make prod-db-seed         - Run production Laravel database seeders"
	@echo "  make prod-db-reset        - Drop all tables, run migrations and seeders on production (destructive)"
	@echo "  make prod-storage-link    - Create public storage symlinks for Laravel services"
	@echo "  make prod-mail-start      - Start Mailu mail server stack on droplet"
	@echo "  make prod-mail-stop       - Stop Mailu mail server stack on droplet"
	@echo "  make prod-mail-restart    - Restart Mailu mail server stack on droplet"
	@echo "  make prod-status          - Show status of all active production containers"
	@echo "  make prod-logs            - Tail output logs from production containers"
	@echo "  make prod-logs-admin      - Tail logs from the admin container"
	@echo "  make prod-logs-report     - Tail logs from the report container"
	@echo "  make prod-logs-api        - Tail logs from the api container"
	@echo "  make prod-logs-front      - Tail logs from the frontend container"
	@echo "  make prod-laravel-logs-api - Tail Laravel log file for API service"
	@echo "  make prod-laravel-logs-admin - Tail Laravel log file for Admin service"
	@echo "  make prod-laravel-logs-report - Tail Laravel log file for Report service"
	@echo "  make prod-nginx-config    - List config files and print default.conf inside Nginx container"
	@echo ""
	@echo "Production Mailu Commands (use: USER=username DOMAIN=example.com PASS=password):"
	@echo "  make prod-mail-user-add   - Create a new mail account"
	@echo "  make prod-mail-user-del   - Delete a mail account"
	@echo "  make prod-mail-user-pass  - Change password for mail account"
	@echo "  make prod-mail-admin-add  - Create a new global mail admin"
	@echo "  make prod-mail-domain-add - Add a new mail domain"
	@echo "  make prod-mail-domain-del - Delete a mail domain"
	@echo "  make prod-mail-restart    - Restart Mailu server containers"
	@echo ""
	@echo "Production Database Commands (use: DBNAME=dbname USER=username PASS=password):"
	@echo "  make prod-db-create       - Create a new Postgres database"
	@echo "  make prod-db-drop         - Delete a Postgres database"
	@echo "  make prod-db-user-add     - Create a new Postgres user"
	@echo "  make prod-db-user-pass    - Change Postgres user password"
	@echo "  make prod-db-user-del     - Delete a Postgres user"
	@echo "  make prod-db-list         - List all databases"
	@echo ""
	@echo "Production Services Commands:"
	@echo "  make prod-scraper-restart - Restart the scraper container"
	@echo "  make prod-scraper-rebuild - Rebuild and restart the scraper container"
	@echo "  make prod-cassandra-cqlsh - Access Cassandra CQL shell"
	@echo "  make prod-cassandra-restart- Restart Cassandra container"
	@echo "  make prod-rabbitmq-restart - Restart RabbitMQ container"
	@echo "  make prod-elastic-restart - Restart Elasticsearch & Kibana containers"
	@echo "  make prod-search-reindex  - Recreate and populate Elasticsearch search indexes on production"

local:
	@echo "🌐 Creating lobbym-network network..."
	docker network create lobbym-network || true

	@echo "🐘 Installing Composer dependencies..."
	$(call run_composer,$(API_DIR),install)
	$(call run_composer,$(ADMIN_DIR),install)
	$(call run_composer,$(REPORT_DIR),install)

	@echo "📦 Installing Node dependencies..."
	if [ ! -d "$(ADMIN_DIR)/node_modules" ]; then $(call run_npm,$(ADMIN_DIR),install); fi
	if [ ! -d "$(FRONT_DIR)/node_modules" ]; then $(call run_pnpm,$(FRONT_DIR),install); fi

	@echo "🐳 Starting Ecosystem Containers..."
	cd local && docker compose up -d --build

	@echo "⏳ Waiting for Cassandra to accept connections..."
	@until docker exec lobbym-cassandra cqlsh -e "describe keyspaces" >/dev/null 2>&1; do \
		echo "Waiting for Cassandra..."; \
		sleep 3; \
	done

	@echo "🔓 Fixing folder permissions..."
	docker exec lobbym-api-php mkdir -p storage/app/payments || true
	docker exec lobbym-api-php chmod -R 777 storage bootstrap/cache || true
	docker exec lobbym-admin-php chmod -R 777 storage bootstrap/cache || true
	docker exec lobbym-report-php chmod -R 777 storage bootstrap/cache || true
	@echo "🔗 Creating Laravel storage symlinks..."
	docker exec lobbym-api-php php artisan storage:link || true
	docker exec lobbym-admin-php php artisan storage:link || true
	docker exec lobbym-report-php php artisan storage:link || true


	@echo "✅ Ecosystem is successfully started in development mode!"

local-front-build:
	@echo "⚙️ Rebuilding local Next.js frontend using temporary container..."
	mkdir -p /home/iandr/.corepack /home/iandr/.pnpm-store
	docker run --rm \
		-v "$(FRONT_DIR):/app" \
		-v "/home/iandr/.corepack:/tmp/corepack" \
		-v "/home/iandr/.pnpm-store:/root/.local/share/pnpm/store" \
		-w /app \
		-e NODE_OPTIONS="--max-old-space-size=1536" \
		-e COREPACK_ENABLE_AUTO_CONFIRM=1 \
		-e COREPACK_HOME=/tmp/corepack \
		node:22-alpine sh -c "corepack enable && corepack prepare pnpm@9.15.2 --activate && pnpm run build"
	@echo "🔄 Starting/Restarting local frontend container in production mode..."
	cd local && FRONT_COMMAND=start docker compose up -d --force-recreate lobbym-front

local-front-dev:
	@echo "🛑 Stopping and removing existing front container..."
	cd local && docker compose stop lobbym-front && docker compose rm -f lobbym-front || true
	@echo "🚀 Starting local frontend container in development mode..."
	cd local && FRONT_COMMAND=dev docker compose up -d --force-recreate lobbym-front

local-db-seed:
	@echo "🛠️ Running Admin Migrations & Seeding..."
	docker exec lobbym-admin-php php artisan migrate:fresh --seed

local-search-reindex:
	@echo "🔍 Reindexing Elasticsearch search engine..."
	docker exec lobbym-api-php php artisan search:reindex

local-clean:
	cd local && docker compose down -v
	docker rm -f lobbym-front || true

local-logs-clear:
	@echo "🧹 Clearing mail_worker logs..."
	docker exec lobbym-api-php sh -c "> /var/www/dev.api.lobbym.com/storage/logs/mail_worker.log"

hosts-add:
	@echo "Adding dev domains to Windows hosts file..."
	@if grep -q "devlobbym.com" /mnt/c/Windows/System32/drivers/etc/hosts; then \
		echo "Domains already exist in hosts file."; \
	else \
		sudo cp /mnt/c/Windows/System32/drivers/etc/hosts /tmp/hosts_dev; \
		sudo sh -c 'echo "127.0.0.1 dev.lobbym.com devapi.lobbym.com devadmin.lobbym.com devreport.lobbym.com devsocket.lobbym.com" >> /tmp/hosts_dev'; \
		sudo cp /tmp/hosts_dev /mnt/c/Windows/System32/drivers/etc/hosts; \
		sudo rm -f /tmp/hosts_dev; \
		echo "Domains added successfully."; \
	fi

hosts-remove:
	@echo "Removing dev domains from Windows hosts file..."
	@sudo cp /mnt/c/Windows/System32/drivers/etc/hosts /tmp/hosts_dev; \
	sudo sed -i '/dev.*lobbym.com/d' /tmp/hosts_dev; \
	sudo cp /tmp/hosts_dev /mnt/c/Windows/System32/drivers/etc/hosts; \
	sudo rm -f /tmp/hosts_dev; \
	echo "Domains removed successfully."

prod-install-deps:
	@echo "📦 Updating packages and installing dependencies..."
	sudo apt-get update
	sudo apt-get install -y ca-certificates curl gnupg lsb-release openssl git
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "📦 Installing Docker..."; \
		sudo mkdir -p /etc/apt/keyrings; \
		curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; \
		echo "deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null; \
		sudo apt-get update; \
		sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin; \
	fi

prod-repos-pull:
	@echo "📂 Creating /var/www directory if it doesn't exist..."
	sudo mkdir -p /var/www
	sudo chmod -R 777 /var/www || true
	@echo "🐙 Cloning or pulling latest updates from Bitbucket..."
	@if [ ! -d "/var/www/$(FRONT_DOMAIN)" ]; then \
		git clone -b $(FRONT_BRANCH) $(FRONT_REPO) /var/www/$(FRONT_DOMAIN); \
		git -C /var/www/$(FRONT_DOMAIN) config core.filemode false; \
	else \
		echo "Pulling latest updates for $(FRONT_DOMAIN) ($(FRONT_BRANCH))..."; \
		git -C /var/www/$(FRONT_DOMAIN) config core.filemode false; \
		git -C /var/www/$(FRONT_DOMAIN) checkout -B $(FRONT_BRANCH) --track origin/$(FRONT_BRANCH) 2>/dev/null || git -C /var/www/$(FRONT_DOMAIN) checkout $(FRONT_BRANCH); \
		git -C /var/www/$(FRONT_DOMAIN) pull; \
	fi
	@if [ ! -d "/var/www/$(API_DOMAIN)" ]; then \
		git clone -b $(API_BRANCH) $(API_REPO) /var/www/$(API_DOMAIN); \
		git -C /var/www/$(API_DOMAIN) config core.filemode false; \
	else \
		echo "Pulling latest updates for $(API_DOMAIN) ($(API_BRANCH))..."; \
		git -C /var/www/$(API_DOMAIN) config core.filemode false; \
		git -C /var/www/$(API_DOMAIN) checkout -B $(API_BRANCH) --track origin/$(API_BRANCH) 2>/dev/null || git -C /var/www/$(API_DOMAIN) checkout $(API_BRANCH); \
		git -C /var/www/$(API_DOMAIN) pull; \
	fi
	@if [ ! -d "/var/www/$(ADMIN_DOMAIN)" ]; then \
		git clone -b $(ADMIN_BRANCH) $(ADMIN_REPO) /var/www/$(ADMIN_DOMAIN); \
		git -C /var/www/$(ADMIN_DOMAIN) config core.filemode false; \
	else \
		echo "Pulling latest updates for $(ADMIN_DOMAIN) ($(ADMIN_BRANCH))..."; \
		git -C /var/www/$(ADMIN_DOMAIN) config core.filemode false; \
		git -C /var/www/$(ADMIN_DOMAIN) checkout -B $(ADMIN_BRANCH) --track origin/$(ADMIN_BRANCH) 2>/dev/null || git -C /var/www/$(ADMIN_DOMAIN) checkout $(ADMIN_BRANCH); \
		git -C /var/www/$(ADMIN_DOMAIN) pull; \
	fi
	@if [ ! -d "/var/www/$(REPORT_DOMAIN)" ]; then \
		git clone -b $(REPORT_BRANCH) $(REPORT_REPO) /var/www/$(REPORT_DOMAIN); \
		git -C /var/www/$(REPORT_DOMAIN) config core.filemode false; \
	else \
		echo "Pulling latest updates for $(REPORT_DOMAIN) ($(REPORT_BRANCH))..."; \
		git -C /var/www/$(REPORT_DOMAIN) config core.filemode false; \
		git -C /var/www/$(REPORT_DOMAIN) checkout -B $(REPORT_BRANCH) --track origin/$(REPORT_BRANCH) 2>/dev/null || git -C /var/www/$(REPORT_DOMAIN) checkout $(REPORT_BRANCH); \
		git -C /var/www/$(REPORT_DOMAIN) pull; \
	fi

prod-env-init:
	@if [ ! -f ".env" ]; then \
		echo "📋 Initializing .env from .env.example..."; \
		cp .env.example .env; \
	fi
	@if grep -q "^API_APP_KEY=\s*$$" .env; then \
		echo "🔑 Generating API_APP_KEY in .env..."; \
		sed -i "s|^API_APP_KEY=.*|API_APP_KEY=base64:$$(openssl rand -base64 32)|" .env; \
	fi
	@if grep -q "^ADMIN_APP_KEY=\s*$$" .env; then \
		echo "🔑 Generating ADMIN_APP_KEY in .env..."; \
		sed -i "s|^ADMIN_APP_KEY=.*|ADMIN_APP_KEY=base64:$$(openssl rand -base64 32)|" .env; \
	fi
	@if grep -q "^REPORT_APP_KEY=\s*$$" .env; then \
		echo "🔑 Generating REPORT_APP_KEY in .env..."; \
		sed -i "s|^REPORT_APP_KEY=.*|REPORT_APP_KEY=base64:$$(openssl rand -base64 32)|" .env; \
	fi
	@if grep -q "^API_JWT_SECRET=\s*$$" .env; then \
		echo "🔑 Generating API_JWT_SECRET in .env..."; \
		sed -i "s|^API_JWT_SECRET=.*|API_JWT_SECRET=$$(openssl rand -base64 32)|" .env; \
	fi
	@if grep -q "^LOG_PASSWORD=\s*$$" .env; then \
		echo "🔑 Generating LOG_PASSWORD in .env..."; \
		sed -i "s|^LOG_PASSWORD=.*|LOG_PASSWORD=$$(openssl rand -base64 12)|" .env; \
	fi

prod-env-generate: prod-env-init
	@python3 production/generate_envs.py

prod-env-clean:
	@echo "🧹 Cleaning generated environment and Nginx config files..."
	rm -f production/enviroment/*.env
	rm -f production/nginx/conf.d/default.conf
	rm -f production/docker-compose.yml

prod-app-start: prod-install-deps prod-repos-pull prod-env-generate
	@echo "🔧 Configuring system limits for Elasticsearch..."
	sudo sysctl -w vm.max_map_count=262144 || true
	@if ! grep -q "vm.max_map_count=262144" /etc/sysctl.conf 2>/dev/null; then \
		echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf > /dev/null; \
	fi
	mkdir -p production/scraper
	@echo "🌐 Creating lobbym-network..."
	sudo docker network create lobbym-network || true

	@echo "🐘 Installing Composer dependencies for production API, Admin, and Report..."
	docker run --rm -v "/var/www/$(API_DOMAIN):/app" -w /app composer:2.6 composer install --ignore-platform-reqs
	docker run --rm -v "/var/www/$(ADMIN_DOMAIN):/app" -w /app composer:2.6 composer install --ignore-platform-reqs
	docker run --rm -v "/var/www/$(REPORT_DOMAIN):/app" -w /app composer:2.6 composer install --ignore-platform-reqs

	@echo "📦 Installing Node dependencies and building Admin assets..."
	if [ ! -d "/var/www/$(ADMIN_DOMAIN)/node_modules" ]; then \
		docker run --rm -v "/var/www/$(ADMIN_DOMAIN):/app" -w /app node:22-alpine npm install; \
	fi
	docker run --rm -v "/var/www/$(ADMIN_DOMAIN):/app" -w /app node:22-alpine npm run build || true

	@echo "📦 Installing Node dependencies and building Report assets..."
	if [ ! -d "/var/www/$(REPORT_DOMAIN)/node_modules" ]; then \
		docker run --rm -v "/var/www/$(REPORT_DOMAIN):/app" -w /app node:22-alpine npm install; \
	fi
	docker run --rm -v "/var/www/$(REPORT_DOMAIN):/app" -w /app node:22-alpine npm run build || true

	@echo "📦 Installing Node dependencies and building Frontend Next.js app..."
	docker run --rm --env-file production/enviroment/front.env -v "/var/www/$(FRONT_DOMAIN):/app" -w /app node:22-alpine sh -c "corepack enable && corepack prepare pnpm@latest --activate && pnpm install --no-frozen-lockfile --ignore-scripts && pnpm run build"

	@echo "🔐 Checking SSL certificates..."
	mkdir -p production/certs
	@if [ ! -f "production/certs/fullchain.pem" ] || [ ! -f "production/certs/privkey.pem" ]; then \
		echo "⚠️ SSL certificates not found. Generating temporary self-signed dummy certificates..."; \
		openssl req -x509 -newkey rsa:2048 -keyout production/certs/privkey.pem -out production/certs/fullchain.pem -days 365 -nodes -subj "/CN=lobbym.com"; \
	fi

	@echo "🚀 Starting Lobbym production application stack..."
	cd production && sudo docker compose up -d --build

	@echo "🔓 Fixing Laravel storage and cache folder permissions..."
	sudo docker exec lobbym-api-php mkdir -p storage/app/payments || true
	sudo docker exec lobbym-api-php chmod -R 777 storage bootstrap/cache || true
	sudo docker exec lobbym-admin-php chmod -R 777 storage bootstrap/cache || true
	sudo docker exec lobbym-report-php chmod -R 777 storage bootstrap/cache || true
	@echo "🔗 Creating Laravel storage symlinks..."
	sudo docker exec lobbym-api-php php artisan storage:link || true
	sudo docker exec lobbym-admin-php php artisan storage:link || true
	sudo docker exec lobbym-report-php php artisan storage:link || true

	@echo "🔑 Generating Application Encryption Keys..."
	sudo docker exec lobbym-api-php php artisan config:clear || true
	sudo docker exec lobbym-admin-php php artisan config:clear || true
	sudo docker exec lobbym-report-php php artisan config:clear || true
	sudo docker exec lobbym-api-php php artisan key:generate --force || true
	sudo docker exec lobbym-admin-php php artisan key:generate --force || true
	sudo docker exec lobbym-report-php php artisan key:generate --force || true

	@echo "🔑 Generating JWT Secret Key for the API..."
	sudo docker exec lobbym-api-php php artisan jwt:secret --force || true

prod-app-stop:
	cd production && sudo docker compose down

prod-app-restart: prod-app-stop prod-app-start

prod-infra-start:
	@echo "🔧 Configuring system limits for Elasticsearch..."
	sudo sysctl -w vm.max_map_count=262144 || true
	@if ! grep -q "vm.max_map_count=262144" /etc/sysctl.conf 2>/dev/null; then \
		echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf > /dev/null; \
	fi
	@echo "🌐 Creating lobbym-network..."
	sudo docker network create lobbym-network || true
	@echo "🔐 Checking SSL certificates..."
	mkdir -p production/certs
	@if [ ! -f "production/certs/fullchain.pem" ] || [ ! -f "production/certs/privkey.pem" ]; then \
		echo "⚠️ SSL certificates not found. Generating temporary self-signed dummy certificates..."; \
		openssl req -x509 -newkey rsa:2048 -keyout production/certs/privkey.pem -out production/certs/fullchain.pem -days 365 -nodes -subj "/CN=lobbym.com"; \
	fi
	@echo "🚀 Starting backend infrastructure..."
	cd production && sudo docker compose up -d --no-deps db redis elasticsearch kibana cassandra rabbitmq nginx filebeat

prod-infra-stop:
	@echo "🛑 Stopping backend infrastructure..."
	cd production && sudo docker compose stop db redis elasticsearch kibana cassandra rabbitmq nginx filebeat

prod-backend-start:
	@echo "🐘 Installing Composer dependencies for production API, Admin, and Report..."
	docker run --rm -v "/var/www/$(API_DOMAIN):/app" -w /app composer:2.6 composer install --ignore-platform-reqs
	docker run --rm -v "/var/www/$(ADMIN_DOMAIN):/app" -w /app composer:2.6 composer install --ignore-platform-reqs
	docker run --rm -v "/var/www/$(REPORT_DOMAIN):/app" -w /app composer:2.6 composer install --ignore-platform-reqs
	@echo "📦 Building Admin and Report assets..."
	if [ ! -d "/var/www/$(ADMIN_DOMAIN)/node_modules" ]; then \
		docker run --rm -v "/var/www/$(ADMIN_DOMAIN):/app" -w /app node:22-alpine npm install; \
	fi
	docker run --rm -v "/var/www/$(ADMIN_DOMAIN):/app" -w /app node:22-alpine npm run build || true
	if [ ! -d "/var/www/$(REPORT_DOMAIN)/node_modules" ]; then \
		docker run --rm -v "/var/www/$(REPORT_DOMAIN):/app" -w /app node:22-alpine npm install; \
	fi
	docker run --rm -v "/var/www/$(REPORT_DOMAIN):/app" -w /app node:22-alpine npm run build || true
	mkdir -p production/scraper
	@echo "🚀 Starting backend services..."
	cd production && sudo docker compose up -d --build --force-recreate lobbym-api-php lobbym-admin-php lobbym-report-php lobbym-scraper lobbym-socket lobbym-email-consumer lobbym-notification-consumer
	@echo "🔓 Fixing Laravel storage and cache folder permissions..."
	sudo docker exec lobbym-api-php mkdir -p storage/app/payments || true
	sudo docker exec lobbym-api-php chmod -R 777 storage bootstrap/cache || true
	sudo docker exec lobbym-admin-php chmod -R 777 storage bootstrap/cache || true
	sudo docker exec lobbym-report-php chmod -R 777 storage bootstrap/cache || true
	@echo "🔗 Creating Laravel storage symlinks..."
	sudo docker exec lobbym-api-php php artisan storage:link || true
	sudo docker exec lobbym-admin-php php artisan storage:link || true
	sudo docker exec lobbym-report-php php artisan storage:link || true
	@echo "🧹 Clearing config cache..."
	sudo docker exec lobbym-api-php php artisan config:clear || true
	sudo docker exec lobbym-admin-php php artisan config:clear || true
	sudo docker exec lobbym-report-php php artisan config:clear || true

prod-backend-stop:
	@echo "🛑 Stopping backend services..."
	cd production && sudo docker compose stop lobbym-api-php lobbym-admin-php lobbym-report-php lobbym-scraper lobbym-socket lobbym-email-consumer

prod-front-start:
	@echo "📦 Installing Node dependencies and building Frontend Next.js app..."
	mkdir -p /root/.corepack /root/.pnpm-store
	docker run --rm \
		--cpus="1.5" \
		--memory="2g" \
		-v "/root/.corepack:/tmp/corepack" \
		-v "/root/.pnpm-store:/root/.local/share/pnpm/store" \
		--env-file production/enviroment/front.env \
		-v "/var/www/$(FRONT_DOMAIN):/app" \
		-w /app \
		-e NODE_OPTIONS="--max-old-space-size=1536" \
		-e COREPACK_ENABLE_AUTO_CONFIRM=1 \
		-e COREPACK_HOME=/tmp/corepack \
		node:22-alpine sh -c "corepack enable && corepack prepare pnpm@9.15.2 --activate && pnpm install --no-frozen-lockfile --ignore-scripts && pnpm run build"
	@echo "🚀 Starting frontend service..."
	cd production && sudo docker compose up -d --build --force-recreate lobbym-front

prod-front-stop:
	@echo "🛑 Stopping frontend service..."
	cd production && sudo docker compose stop lobbym-front


prod-nginx-restart:
	cd production && sudo docker compose restart nginx

prod-front-build:
	@echo "⚙️ Regenerating environment files..."
	$(MAKE) prod-env-generate
	@echo "📦 Rebuilding Frontend Next.js app..."
	mkdir -p /root/.corepack /root/.pnpm-store
	docker run --rm \
		--cpus="1.5" \
		--memory="2g" \
		-v "/root/.corepack:/tmp/corepack" \
		-v "/root/.pnpm-store:/root/.local/share/pnpm/store" \
		--env-file production/enviroment/front.env \
		-v "/var/www/$(FRONT_DOMAIN):/app" \
		-w /app \
		-e NODE_OPTIONS="--max-old-space-size=1536" \
		-e COREPACK_ENABLE_AUTO_CONFIRM=1 \
		-e COREPACK_HOME=/tmp/corepack \
		node:22-alpine sh -c "corepack enable && corepack prepare pnpm@9.15.2 --activate && pnpm install --no-frozen-lockfile --ignore-scripts && pnpm run build"
	@echo "🔄 Restarting frontend container..."
	cd production && sudo docker compose up -d --force-recreate lobbym-front


prod-mail-start: prod-install-deps
	@echo "📂 Creating Mailu directories..."
	mkdir -p mailu/data mailu/config mailu/dkim mailu/mail mailu/overrides mailu/filter mailu/webmail mailu/certs
	@echo "🔐 Configuring TLS and generating certs if local..."
	@if [ "$(MODE)" = "local" ]; then \
		TLS_FLAVOR="cert"; \
		HOSTNAMES="mail.lobbym.com,lobbym.com,localhost,127.0.0.1"; \
		if [ ! -f "mailu/certs/cert.pem" ]; then \
			openssl req -x509 -newkey rsa:4096 \
			  -keyout mailu/certs/key.pem -out mailu/certs/cert.pem \
			  -sha256 -days 3650 -nodes \
			  -subj "/CN=lobbym.com" \
			  -addext "subjectAltName = DNS:lobbym.com, DNS:mail.lobbym.com, DNS:localhost, IP:127.0.0.1"; \
		fi; \
	else \
		TLS_FLAVOR="letsencrypt"; \
		HOSTNAMES="mail.lobbym.com"; \
	fi; \
	if [ ! -f "mailu/mailu.env" ]; then \
		echo "⚙️ Generating mailu.env configuration..."; \
		echo "DEBUG=false" > mailu/mailu.env; \
		echo "BYPASS_DNS_CHECK=true" >> mailu/mailu.env; \
		echo "DNS_RESOLVER=172.22.0.254" >> mailu/mailu.env; \
		echo "DOMAIN=lobbym.com" >> mailu/mailu.env; \
		echo "HOSTNAMES=$$HOSTNAMES" >> mailu/mailu.env; \
		echo "POSTMASTER=admin" >> mailu/mailu.env; \
		echo "SECRET_KEY=$$(openssl rand -base64 32)" >> mailu/mailu.env; \
		echo "MESSAGE_SIZE_LIMIT=50000000" >> mailu/mailu.env; \
		echo "SESSION_TIMEOUT=3600" >> mailu/mailu.env; \
		echo "AUTH_DRIVER=internal" >> mailu/mailu.env; \
		echo "TLS_FLAVOR=$$TLS_FLAVOR" >> mailu/mailu.env; \
		echo "DB_FLAVOR=sqlite" >> mailu/mailu.env; \
		echo "WEBMAIL=snappymail" >> mailu/mailu.env; \
		echo "ADMIN=true" >> mailu/mailu.env; \
		echo "WEBROOT=/" >> mailu/mailu.env; \
		echo "WEB_ADMIN=/admin" >> mailu/mailu.env; \
		echo "WEB_WEBMAIL=/webmail" >> mailu/mailu.env; \
		echo "WEB_STATIC=/static" >> mailu/mailu.env; \
		echo "SITENAME=Lobbym Mail" >> mailu/mailu.env; \
		echo "WEBSITE=https://lobbym.com" >> mailu/mailu.env; \
		echo "ANTISPAM=rspamd" >> mailu/mailu.env; \
		echo "ANTIVIRUS=none" >> mailu/mailu.env; \
		echo "SCAN_MACROS=true" >> mailu/mailu.env; \
		echo "SERVICES=imap,smtp,pop3,antispam,webmail,admin,front" >> mailu/mailu.env; \
		echo "SUBNET=172.22.0.0/16" >> mailu/mailu.env; \
	fi
	@echo "🌐 Creating lobbym-network..."
	sudo docker network create lobbym-network || true
	@echo "🐳 Starting Mailu stack..."
	cd mailu && sudo docker compose --env-file mailu.env up -d

prod-mail-stop:
	cd mailu && sudo docker compose down

prod-mail-restart: prod-mail-stop prod-mail-start

prod-status:
	@echo "--- Lobbym Application Containers ---"
	cd production && sudo docker compose ps
	@echo ""
	@echo "--- Lobbym Mail (Mailu) Containers ---"
	cd mailu && sudo docker compose ps

prod-logs:
	cd production && sudo docker compose logs -f --tail=100

prod-logs-admin:
	cd production && sudo docker compose logs -f --tail=100 lobbym-admin-php

prod-logs-report:
	cd production && sudo docker compose logs -f --tail=100 lobbym-report-php

prod-logs-api:
	cd production && sudo docker compose logs -f --tail=100 lobbym-api-php

prod-logs-front:
	cd production && sudo docker compose logs -f --tail=100 lobbym-front

prod-logs-consumer:
	cd production && sudo docker compose logs -f --tail=100 lobbym-email-consumer

prod-laravel-logs-api:
	tail -n 100 -f /var/www/$(API_DOMAIN)/storage/logs/laravel.log

prod-laravel-logs-admin:
	tail -n 100 -f /var/www/$(ADMIN_DOMAIN)/storage/logs/laravel.log

prod-laravel-logs-report:
	tail -n 100 -f /var/www/$(REPORT_DOMAIN)/storage/logs/laravel.log

prod-laravel-logs-consumer:
	tail -n 100 -f /var/www/$(API_DOMAIN)/storage/logs/mail_worker.log

prod-nginx-config:
	@echo "📂 Listing Nginx config directory inside container..."
	sudo docker exec lobbym-nginx-proxy ls -la /etc/nginx/conf.d
	@echo ""
	@echo "📄 Compiled default.conf configuration inside container..."
	sudo docker exec lobbym-nginx-proxy cat /etc/nginx/conf.d/default.conf

prod-mail-user-add:
	cd mailu && sudo docker compose exec admin flask mailu user "$(USER)" "$(DOMAIN)" "$(PASS)"

prod-mail-user-del:
	cd mailu && sudo docker compose exec admin flask mailu user-delete "$(USER)@$(DOMAIN)" --really

prod-mail-user-pass:
	cd mailu && sudo docker compose exec admin flask mailu password "$(USER)" "$(DOMAIN)" "$(PASS)"

prod-mail-admin-add:
	cd mailu && sudo docker compose exec admin flask mailu admin "$(USER)" "$(DOMAIN)" "$(PASS)"

prod-mail-domain-add:
	cd mailu && sudo docker compose exec admin flask mailu domain "$(DOMAIN)"

prod-mail-domain-del:
	cd mailu && sudo docker compose exec admin flask mailu domain-delete "$(DOMAIN)"

prod-mail-restart:
	cd mailu && sudo docker compose restart front resolver admin imap smtp antispam webmail

prod-db-create:
	sudo docker exec -it lobbym-postgres psql -U postgres -c "CREATE DATABASE $(DBNAME);"

prod-db-drop:
	sudo docker exec -it lobbym-postgres psql -U postgres -c "DROP DATABASE $(DBNAME);"

prod-db-user-add:
	sudo docker exec -it lobbym-postgres psql -U postgres -c "CREATE USER $(USER) WITH PASSWORD '$(PASS)';"

prod-db-user-pass:
	sudo docker exec -it lobbym-postgres psql -U postgres -c "ALTER USER $(USER) WITH PASSWORD '$(PASS)';"

prod-db-user-del:
	sudo docker exec -it lobbym-postgres psql -U postgres -c "DROP USER $(USER);"

prod-db-list:
	sudo docker exec -it lobbym-postgres psql -U postgres -c "\l"

prod-db-migrate:
	@echo "🛠️ Running production database migrations..."
	sudo docker exec lobbym-admin-php php artisan migrate --force

prod-db-seed:
	@echo "🌱 Running production database seeding..."
	sudo docker exec lobbym-admin-php php artisan db:seed --force

prod-db-reset:
	@echo "⚠️ Resetting production database '$(ADMIN_DB_DATABASE)' using Postgres container..."
	sudo docker exec lobbym-postgres psql -U postgres -c "DROP DATABASE IF EXISTS $(ADMIN_DB_DATABASE) WITH (FORCE);"
	sudo docker exec lobbym-postgres psql -U postgres -c "CREATE DATABASE $(ADMIN_DB_DATABASE);"

prod-storage-link:
	@echo "🔗 Creating Laravel storage symlinks on production..."
	sudo docker exec lobbym-api-php php artisan storage:link || true
	sudo docker exec lobbym-admin-php php artisan storage:link || true
	sudo docker exec lobbym-report-php php artisan storage:link || true

prod-scraper-restart:
	cd production && sudo docker compose restart lobbym-scraper

prod-scraper-rebuild:
	cd production && sudo docker compose up -d --build lobbym-scraper

prod-cassandra-cqlsh:
	sudo docker exec -it lobbym-cassandra cqlsh

prod-cassandra-restart:
	cd production && sudo docker compose restart cassandra

prod-rabbitmq-restart:
	cd production && sudo docker compose restart rabbitmq

prod-elastic-restart:
	cd production && sudo docker compose restart elasticsearch kibana

prod-search-reindex:
	@echo "🔍 Reindexing Elasticsearch search engine on production..."
	sudo docker exec lobbym-api-php php artisan search:reindex
