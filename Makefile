ROOT_DIR = /home/iandr
API_DIR = $(ROOT_DIR)/dev.api.lobbym.com
ADMIN_DIR = $(ROOT_DIR)/dev.admin.lobbym.com
FRONT_DIR = $(ROOT_DIR)/dev.front.lobbym.com
REPORT_DIR = $(ROOT_DIR)/dev.report.lobbym.com

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

.PHONY: help local local-clean hosts-add hosts-remove \
        prod-install-deps prod-app-start prod-app-stop prod-app-restart \
        prod-mail-start prod-mail-stop prod-mail-restart prod-status prod-logs \
        prod-mail-user-add prod-mail-user-del prod-mail-user-pass prod-mail-admin-add \
        prod-mail-domain-add prod-mail-domain-del prod-mail-restart \
        prod-db-create prod-db-drop prod-db-user-add prod-db-user-pass prod-db-user-del prod-db-list \
        prod-scraper-restart prod-scraper-rebuild prod-cassandra-cqlsh prod-cassandra-restart \
        prod-rabbitmq-restart prod-elastic-restart

help:
	@echo "Lobbym Infrastructure Management Console"
	@echo "========================================="
	@echo "Local Environment Commands:"
	@echo "  make local            - Build and start the entire local development ecosystem"
	@echo "  make local-clean      - Stop and clean local docker compose containers and volumes"
	@echo "  make hosts-add        - Add dev domains to Windows hosts file"
	@echo "  make hosts-remove     - Remove dev domains from Windows hosts file"
	@echo ""
	@echo "Production (Droplet) Commands:"
	@echo "  make prod-install-deps- Install system ca-certs, openssl, and docker-ce on VPS"
	@echo "  make prod-app-start   - Start main Lobbym application stack on droplet"
	@echo "  make prod-app-stop    - Stop main Lobbym application stack on droplet"
	@echo "  make prod-app-restart - Restart main Lobbym application stack on droplet"
	@echo "  make prod-mail-start  - Start Mailu mail server stack on droplet"
	@echo "  make prod-mail-stop   - Stop Mailu mail server stack on droplet"
	@echo "  make prod-mail-restart- Restart Mailu mail server stack on droplet"
	@echo "  make prod-status      - Show status of all active production containers"
	@echo "  make prod-logs        - Tail output logs from production containers"
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
	docker exec lobbym-api-php chmod -R 777 storage bootstrap/cache || true
	docker exec lobbym-admin-php chmod -R 777 storage bootstrap/cache || true
	docker exec lobbym-report-php chmod -R 777 storage bootstrap/cache || true

	@echo "🛠️ Running Admin Migrations & Seeding..."
	docker exec lobbym-admin-php php artisan migrate:fresh --seed

	@echo "✅ Ecosystem is successfully started in development mode!"

local-clean:
	cd local && docker compose down -v
	docker rm -f lobbym-front || true

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
	sudo apt-get install -y ca-certificates curl gnupg lsb-release openssl
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "📦 Installing Docker..."; \
		sudo mkdir -p /etc/apt/keyrings; \
		curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; \
		echo "deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null; \
		sudo apt-get update; \
		sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin; \
	fi

prod-app-start: prod-install-deps
	@echo "🔧 Configuring system limits for Elasticsearch..."
	sudo sysctl -w vm.max_map_count=262144 || true
	@if ! grep -q "vm.max_map_count=262144" /etc/sysctl.conf 2>/dev/null; then \
		echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf > /dev/null; \
	fi
	mkdir -p production/scraper
	@echo "🌐 Creating lobbym-network..."
	sudo docker network create lobbym-network || true

	@echo "🐘 Installing Composer dependencies for production API, Admin, and Report..."
	docker run --rm -v "/var/www/dev.api.lobbym.com:/app" -w /app composer:2.6 composer install --ignore-platform-reqs
	docker run --rm -v "/var/www/dev.admin.lobbym.com:/app" -w /app composer:2.6 composer install --ignore-platform-reqs
	docker run --rm -v "/var/www/dev.report.lobbym.com:/app" -w /app composer:2.6 composer install --ignore-platform-reqs

	@echo "📦 Installing Node dependencies and building Admin assets..."
	if [ ! -d "/var/www/dev.admin.lobbym.com/node_modules" ]; then \
		docker run --rm -v "/var/www/dev.admin.lobbym.com:/app" -w /app node:22-alpine npm install; \
	fi
	docker run --rm -v "/var/www/dev.admin.lobbym.com:/app" -w /app node:22-alpine npm run build || true

	@echo "📦 Installing Node dependencies and building Frontend Next.js app..."
	docker run --rm -v "/var/www/dev.lobbym.com:/app" -w /app node:22-alpine sh -c "corepack enable && corepack prepare pnpm@latest --activate && pnpm install --no-frozen-lockfile && pnpm run build"

	@echo "🚀 Starting Lobbym production application stack..."
	cd production && sudo docker compose up -d --build

prod-app-stop:
	cd production && sudo docker compose down

prod-app-restart: prod-app-stop prod-app-start

prod-mail-start: prod-install-deps
	@echo "📂 Creating Mailu directories..."
	mkdir -p production/mailu/data production/mailu/config production/mailu/dkim production/mailu/mail production/mailu/overrides production/mailu/filter production/mailu/webmail production/mailu/certs
	@echo "🔐 Configuring TLS and generating certs if local..."
	@if [ "$(MODE)" = "local" ]; then \
		TLS_FLAVOR="cert"; \
		HOSTNAMES="mail.lobbym.com,lobbym.com,localhost,127.0.0.1"; \
		if [ ! -f "production/mailu/certs/cert.pem" ]; then \
			openssl req -x509 -newkey rsa:4096 \
			  -keyout production/mailu/certs/key.pem -out production/mailu/certs/cert.pem \
			  -sha256 -days 3650 -nodes \
			  -subj "/CN=lobbym.com" \
			  -addext "subjectAltName = DNS:lobbym.com, DNS:mail.lobbym.com, DNS:localhost, IP:127.0.0.1"; \
		fi; \
	else \
		TLS_FLAVOR="letsencrypt"; \
		HOSTNAMES="mail.lobbym.com"; \
	fi; \
	if [ ! -f "production/mailu.env" ]; then \
		echo "⚙️ Generating mailu.env configuration..."; \
		echo "DEBUG=false" > production/mailu.env; \
		echo "BYPASS_DNS_CHECK=true" >> production/mailu.env; \
		echo "DNS_RESOLVER=172.22.0.254" >> production/mailu.env; \
		echo "DOMAIN=lobbym.com" >> production/mailu.env; \
		echo "HOSTNAMES=$$HOSTNAMES" >> production/mailu.env; \
		echo "POSTMASTER=admin" >> production/mailu.env; \
		echo "SECRET_KEY=$$(openssl rand -base64 32)" >> production/mailu.env; \
		echo "MESSAGE_SIZE_LIMIT=50000000" >> production/mailu.env; \
		echo "SESSION_TIMEOUT=3600" >> production/mailu.env; \
		echo "AUTH_DRIVER=internal" >> production/mailu.env; \
		echo "TLS_FLAVOR=$$TLS_FLAVOR" >> production/mailu.env; \
		echo "DB_FLAVOR=sqlite" >> production/mailu.env; \
		echo "WEBMAIL=snappymail" >> production/mailu.env; \
		echo "ADMIN=true" >> production/mailu.env; \
		echo "WEBROOT=/" >> production/mailu.env; \
		echo "WEB_ADMIN=/admin" >> production/mailu.env; \
		echo "WEB_WEBMAIL=/webmail" >> production/mailu.env; \
		echo "WEB_STATIC=/static" >> production/mailu.env; \
		echo "SITENAME=Lobbym Mail" >> production/mailu.env; \
		echo "WEBSITE=https://lobbym.com" >> production/mailu.env; \
		echo "ANTISPAM=rspamd" >> production/mailu.env; \
		echo "ANTIVIRUS=none" >> production/mailu.env; \
		echo "SCAN_MACROS=true" >> production/mailu.env; \
		echo "SERVICES=imap,smtp,pop3,antispam,webmail,admin,front" >> production/mailu.env; \
		echo "SUBNET=172.22.0.0/16" >> production/mailu.env; \
	fi
	@echo "🌐 Creating lobbym-network..."
	sudo docker network create lobbym-network || true
	@echo "🐳 Starting Mailu stack..."
	cd production && sudo docker compose -f mailu.yml --env-file mailu.env up -d

prod-mail-stop:
	cd production && sudo docker compose -f mailu.yml down

prod-mail-restart: prod-mail-stop prod-mail-start

prod-status:
	@echo "--- Lobbym Application Containers ---"
	cd production && sudo docker compose ps
	@echo ""
	@echo "--- Lobbym Mail (Mailu) Containers ---"
	cd production && sudo docker compose -f mailu.yml ps

prod-logs:
	cd production && sudo docker compose logs -f --tail=100

prod-mail-user-add:
	cd production && sudo docker compose -f mailu.yml exec admin flask mailu user "$(USER)" "$(DOMAIN)" "$(PASS)"

prod-mail-user-del:
	cd production && sudo docker compose -f mailu.yml exec admin flask mailu user-delete "$(USER)@$(DOMAIN)" --really

prod-mail-user-pass:
	cd production && sudo docker compose -f mailu.yml exec admin flask mailu password "$(USER)" "$(DOMAIN)" "$(PASS)"

prod-mail-admin-add:
	cd production && sudo docker compose -f mailu.yml exec admin flask mailu admin "$(USER)" "$(DOMAIN)" "$(PASS)"

prod-mail-domain-add:
	cd production && sudo docker compose -f mailu.yml exec admin flask mailu domain "$(DOMAIN)"

prod-mail-domain-del:
	cd production && sudo docker compose -f mailu.yml exec admin flask mailu domain-delete "$(DOMAIN)"

prod-mail-restart:
	cd production && sudo docker compose -f mailu.yml restart front resolver admin imap smtp antispam webmail

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
