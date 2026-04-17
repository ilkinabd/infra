#### create infra for lobbym
```bash 
docker network create lobbym-network 

cd /home/iandr/lobbym-infra
docker compose up -d

cd /home/iandr/dev.api.lobbym.com/deployments
docker compose up -d --build

cd /home/iandr/dev.admin.lobbym.com/deployments
docker compose up -d --build
```