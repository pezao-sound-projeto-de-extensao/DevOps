#!/bin/bash

sleep 100
exec > >(tee -a /var/log/web-bootstrap.log) 2>&1
# Note: We do NOT use 'set -e' globally to allow some failures (like docker pull)
# Individual commands that MUST succeed are checked explicitly

export DEBIAN_FRONTEND=noninteractive

if command -v apt-get >/dev/null 2>&1; then
	apt-get update -y
	apt-get install -y nfs-common nginx docker.io
elif command -v dnf >/dev/null 2>&1; then
	dnf makecache -y
	dnf install -y nfs-utils nginx docker
elif command -v yum >/dev/null 2>&1; then
	yum makecache -y
	yum install -y nfs-utils nginx docker
else
	echo "No supported package manager found (apt, dnf, yum)." >&2
	exit 1
fi

systemctl enable nginx

if systemctl list-unit-files | grep -q '^docker\.service'; then
	systemctl enable docker
	systemctl start docker || systemctl restart docker || true
elif systemctl list-unit-files | grep -q '^docker\.socket'; then
	systemctl enable docker.socket
	systemctl start docker.socket || systemctl restart docker.socket || true
fi

# Wait for Docker daemon and capture status for troubleshooting.
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
	journalctl -u docker --no-pager -n 100 || true
fi

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
		mkdir -p /mnt/efs-psnd/content/frontend
		echo "EFS mounted on web instance" > /var/log/efs-mount-status.log
		exit 0
	fi

	if timeout 25s mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,soft,timeo=50,retrans=2,noresvport __EFS_DNS__:/ /mnt/efs-psnd; then
		mkdir -p /mnt/efs-psnd/content/frontend
		echo "EFS mounted on web instance" > /var/log/efs-mount-status.log
		exit 0
	fi

	echo "Tentativa de mount EFS falhou ($i/30). Aguardando..."
	sleep 10
done

echo "EFS NOT mounted on web instance" > /var/log/efs-mount-status.log
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

# Pull e run da imagem do frontend
echo "[$(date)] Pulling Docker image herculessp/pezao-sound-web:main" >> /var/log/pezao-sound-web-bootstrap.log
if docker info >/dev/null 2>&1 && docker pull herculessp/pezao-sound-web:main >> /var/log/pezao-sound-web-bootstrap.log 2>&1; then
	echo "[$(date)] Docker image pull successful" >> /var/log/pezao-sound-web-bootstrap.log
	docker rm -f pezao-sound-web >/dev/null 2>&1 || true
	docker run -d \
		--name pezao-sound-web \
		--restart unless-stopped \
		-p 5173:80 \
		-e VITE_API_BASE_URL="http://${alb_dns}/api" \
		herculessp/pezao-sound-web:main >> /var/log/pezao-sound-web-bootstrap.log 2>&1
	echo "[$(date)] Docker container started" >> /var/log/pezao-sound-web-bootstrap.log
else
	echo "[$(date)] WARNING: Docker unavailable or image pull failed. Check daemon and Docker Hub access." >> /var/log/pezao-sound-web-bootstrap.log
	echo "Expected: herculessp/pezao-sound-web:main" >> /var/log/pezao-sound-web-bootstrap.log
fi
docker ps -a > /var/log/pezao-sound-web-container.log

tee /etc/nginx/sites-available/default >/dev/null <<'EOF'
upstream pezao_web {
	server 127.0.0.1:5173;
}

server {
	listen 80 default_server;
	listen [::]:80 default_server;

	server_name _;

	location / {
		proxy_pass http://pezao_web;
		proxy_http_version 1.1;
		proxy_set_header Upgrade $http_upgrade;
		proxy_set_header Connection 'upgrade';
		proxy_set_header Host $host;
		proxy_cache_bypass $http_upgrade;
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto $scheme;
	}
}
EOF

if ! mountpoint -q /mnt/efs-psnd; then
	mkdir -p /mnt/efs-psnd/content/frontend
fi

chown -R www-data:www-data /mnt/efs-psnd/content/frontend || true
chmod -R 755 /mnt/efs-psnd/content/frontend || true

nginx -t

systemctl restart nginx
