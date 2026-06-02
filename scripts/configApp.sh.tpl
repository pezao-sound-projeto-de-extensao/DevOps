#!/bin/bash
set -e

sleep 100
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y docker.io nginx nfs-common

sudo systemctl enable docker
sudo systemctl restart docker

sudo systemctl enable nginx
sudo systemctl restart nginx

sudo mkdir -p /mnt/efs-psnd

if ! sudo grep -q '${efs_dns}:/ /mnt/efs-psnd' /etc/fstab; then
  echo '${efs_dns}:/ /mnt/efs-psnd nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,soft,timeo=50,retrans=2,noresvport,_netdev,nofail 0 0' | sudo tee -a /etc/fstab >/dev/null
fi

sudo tee /usr/local/bin/mount-efs-psnd.sh >/dev/null <<'EOF'
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

sudo sed -i "s#__EFS_DNS__#${efs_dns}#g" /usr/local/bin/mount-efs-psnd.sh
sudo chmod +x /usr/local/bin/mount-efs-psnd.sh

sudo tee /etc/systemd/system/efs-mount-psnd.service >/dev/null <<'EOF'
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

sudo systemctl daemon-reload
sudo systemctl enable efs-mount-psnd.service
sudo systemctl start efs-mount-psnd.service || true

sudo mkdir -p /mnt/efs-psnd/images/backend /mnt/efs-psnd/content/backend

sudo mkdir -p /opt/stockflow

sudo tee /opt/stockflow/.env >/dev/null <<EOF
DB_HOST=${db_private_ip}
DB_NAME=${db_name}
DB_PASSWORD=${db_password}
DB_USERNAME=${db_username}
DB_PORT=${db_port}
EOF

sudo docker pull ${docker_image}
for i in $(seq 1 24); do
  if mountpoint -q /mnt/efs-psnd; then
    sudo docker save ${docker_image} -o /mnt/efs-psnd/images/backend/backend-image.tar
    break
  fi
  sleep 5
done

sudo docker rm -f ${container_name} || true

sudo docker run -d \
  --name ${container_name} \
  --restart always \
  --env-file /opt/stockflow/.env \
  --network host \
  ${docker_image}

sudo cat > /etc/nginx/sites-available/default <<EOF
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