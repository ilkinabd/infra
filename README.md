# Lobbym Infrastructure Manager

This repository consolidates the local development environments and the production server deployment configurations for all Lobbym repositories (Frontend, API, Admin, and Report).

---

## 🛠️ Local Development Setup

To run the local development ecosystem on your WSL/Ubuntu machine:

### 1. Configure Dev Hosts File
Add routing mapping entries to resolve local domain URLs (`dev.lobbym.com`, `devapi.lobbym.com`, etc.) to localhost.
```bash
make hosts-add
```
*(This appends loopback routing directly inside the Windows hosts file `/mnt/c/Windows/System32/drivers/etc/hosts`).*

### 2. Start the Stack
Boot all backend apps, frontend (running `pnpm run dev`), queues, and database engines (PostgreSQL, Cassandra, Elasticsearch, Redis, RabbitMQ):
```bash
make local
```
*Note: This target will automatically query Cassandra and wait until port 9042 is fully available before executing migrations and database seeding.*

### 3. Tear Down / Clean Local Stack
Stop all local containers and clear active volumes:
```bash
make local-clean
```

### 4. Remove Dev Hosts File Mappings
Restore your Windows hosts file:
```bash
make hosts-remove
```

---

## 🚀 Production Server Deployment

You can deploy the entire Lobbym ecosystem onto a clean, empty Ubuntu server with a single command.

### Prerequisites
Before running, make sure your server's SSH key is registered on Bitbucket, as the installation targets clone the codebases directly via SSH.

### 1. Clone the Infrastructure Repository
```bash
git clone git@bitbucket.org:myavuz85/dev.infra.lobbym.com.git /root/dev.infra.lobbym.com
cd /root/dev.infra.lobbym.com
```

### 2. Configure Domain and Protocol
Copy the template `.env.example` to `.env` and set your preferred domain and protocol (HTTP or HTTPS):
```bash
cp .env.example .env
```
Open `.env` and configure:
```env
APP_DOMAIN=lobbym.com
APP_PROTOCOL=https
```

### 3. Place SSL Certificates (If using HTTPS)
If `APP_PROTOCOL=https` is selected, ensure Nginx can find your SSL certificates:
1. Create a `certs` folder: `mkdir -p production/certs`
2. Place your certificate files inside as `production/certs/fullchain.pem` and `production/certs/privkey.pem`.
*(For Cloudflare setups, use the Cloudflare Origin CA certificate files).*

### 4. Boot the Production Stack
Run this target to install Docker, clone all codebases from Bitbucket, compile CSS/JS assets, generate environments/configs, and start the containers:
```bash
make prod-app-start
```

---

## 📂 Production Administration Commands

### Database Migrations & Seeding
* **Run Standard Migrations**:
  Apply any new database schema changes safely without dropping tables:
  ```bash
  make prod-db-migrate
  ```
* **Run Database Seeders**:
  ```bash
  make prod-db-seed
  ```

### Rebuilding & Updating
* **Fast Frontend Update**:
  If you have pushed updates to the frontend codebase, you can pull, compile a new production Next.js build, and restart the frontend container in one step:
  ```bash
  make prod-front-build
  ```
* **Rebuild Scraper**:
  ```bash
  make prod-scraper-rebuild
  ```
* **Restart Services**:
  ```bash
  make prod-scraper-restart
  make prod-cassandra-restart
  make prod-rabbitmq-restart
  make prod-elastic-restart
  ```

### Status & Logs
* **List Container Status**:
  ```bash
  make prod-status
  ```
* **Tail Container Logs**:
  ```bash
  make prod-logs
  ```
* **Stop Application Stack**:
  ```bash
  make prod-app-stop
  ```

---

## 📧 Production Mail Server (Mailu)
* **Start Mail Services**:
  ```bash
  make prod-mail-start
  ```
* **Stop Mail Services**:
  ```bash
  make prod-mail-stop
  ```
* **Mail Administration**:
  * Create User: `make prod-mail-user-add USER=admin DOMAIN=lobbym.com PASS=mypassword`
  * Delete User: `make prod-mail-user-del USER=admin DOMAIN=lobbym.com`
  * Add Domain: `make prod-mail-domain-add DOMAIN=lobbym.com`
  * Delete Domain: `make prod-mail-domain-del DOMAIN=lobbym.com`
