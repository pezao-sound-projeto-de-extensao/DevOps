#!/bin/bash

sleep 100
exec > >(tee -a /var/log/app-bootstrap.log) 2>&1

export DEBIAN_FRONTEND=noninteractive

if command -v apt-get >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y docker.io nginx nfs-common
elif command -v dnf >/dev/null 2>&1; then
  dnf makecache -y
  dnf install -y docker nginx nfs-utils
elif command -v yum >/dev/null 2>&1; then
  yum makecache -y
  yum install -y docker nginx nfs-utils
else
  echo "No supported package manager found." >&2
  exit 1
fi

systemctl enable docker
if systemctl list-unit-files | grep -q '^docker\.service'; then
  systemctl start docker || systemctl restart docker || true
elif systemctl list-unit-files | grep -q '^docker\.socket'; then
  systemctl enable docker.socket
  systemctl start docker.socket || true
fi

for i in $(seq 1 15); do
  if docker info >/dev/null 2>&1; then
    echo "Docker daemon is ready"
    break
  fi
  echo "Waiting Docker daemon... ($i/15)"
  sleep 2
done

if ! docker info >/dev/null 2>&1; then
  echo "WARNING: Docker daemon not ready after retries"
  systemctl status docker --no-pager || true
fi

systemctl enable nginx
systemctl restart nginx

mkdir -p /mnt/efs-psnd

if ! grep -q '${efs_dns}:/ /mnt/efs-psnd' /etc/fstab; then
  echo '${efs_dns}:/ /mnt/efs-psnd nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,soft,timeo=50,retrans=2,noresvport,_netdev,nofail 0 0' | tee -a /etc/fstab >/dev/null
fi

tee /usr/local/bin/mount-efs-psnd.sh >/dev/null <<'EOF'
#!/bin/bash
set -e

mkdir -p /mnt/efs-psnd

for i in $(seq 1 30); do
  if mountpoint -q /mnt/efs-psnd; then
    mkdir -p /mnt/efs-psnd/images/backend /mnt/efs-psnd/content/backend
    echo "EFS mounted on app instance" > /var/log/efs-mount-status.log
    exit 0
  fi

  if timeout 25s mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,soft,timeo=50,retrans=2,noresvport __EFS_DNS__:/ /mnt/efs-psnd; then
    mkdir -p /mnt/efs-psnd/images/backend /mnt/efs-psnd/content/backend
    echo "EFS mounted on app instance" > /var/log/efs-mount-status.log
    exit 0
  fi

  echo "Tentativa de mount EFS falhou ($i/30). Aguardando..."
  sleep 10
done

echo "EFS NOT mounted on app instance" > /var/log/efs-mount-status.log
exit 1
EOF

sed -i "s#__EFS_DNS__#${efs_dns}#g" /usr/local/bin/mount-efs-psnd.sh
chmod +x /usr/local/bin/mount-efs-psnd.sh

tee /etc/systemd/system/efs-mount-psnd.service >/dev/null <<'EOF'
[Unit]
Description=Mount EFS for Pezao Sound
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/mount-efs-psnd.sh
RemainAfterExit=yes
Restart=on-failure
RestartSec=15

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable efs-mount-psnd.service
systemctl start efs-mount-psnd.service || true

mkdir -p /mnt/efs-psnd/images/backend /mnt/efs-psnd/content/backend

mkdir -p /opt/stockflow

tee /opt/stockflow/.env >/dev/null <<EOF
DB_HOST=${db_private_ip}
DB_NAME=${db_name}
DB_PASSWORD=${db_password}
DB_USERNAME=${db_username}
DB_PORT=${db_port}
SPRING_DATASOURCE_URL=jdbc:mysql://${db_private_ip}:${db_port}/${db_name}?allowPublicKeyRetrieval=true&useSSL=false
SPRING_DATASOURCE_USERNAME=${db_username}
SPRING_DATASOURCE_PASSWORD=${db_password}
SPRING_JPA_DATABASE_PLATFORM=org.hibernate.dialect.MySQL8Dialect
SPRING_JPA_HIBERNATE_DDL_AUTO=update
EOF

echo "[$(date)] Pulling Docker image ${docker_image}" >> /var/log/app-bootstrap.log
if docker info >/dev/null 2>&1 && docker pull ${docker_image} >> /var/log/app-bootstrap.log 2>&1; then
  echo "[$(date)] Docker image pull successful" >> /var/log/app-bootstrap.log

  for i in $(seq 1 24); do
    if mountpoint -q /mnt/efs-psnd; then
      docker save ${docker_image} -o /mnt/efs-psnd/images/backend/backend-image.tar
      break
    fi
    sleep 5
  done

  docker rm -f ${container_name} >/dev/null 2>&1 || true

  docker run -d \
    --name ${container_name} \
    --restart always \
    --env-file /opt/stockflow/.env \
    --network host \
    ${docker_image}
  echo "[$(date)] Container ${container_name} started" >> /var/log/app-bootstrap.log
else
  echo "[$(date)] WARNING: Docker unavailable or image pull failed for ${docker_image}" >> /var/log/app-bootstrap.log
fi
docker ps -a > /var/log/app-container.log

cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

nginx -t
systemctl restart nginx