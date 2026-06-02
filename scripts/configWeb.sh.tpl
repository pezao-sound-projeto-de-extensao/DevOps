#!/bin/bash

sleep 100
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y nfs-common nginx

sudo systemctl enable nginx

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

cat > /var/www/html/index.html <<'EOF'
${html_content}
EOF

chown www-data:www-data /var/www/html/index.html
chmod 644 /var/www/html/index.html

if mountpoint -q /mnt/efs-psnd; then
	sudo mkdir -p /mnt/efs-psnd/content/frontend
	sudo tee /mnt/efs-psnd/content/frontend/index.html >/dev/null <<'EOF'
${html_content}
EOF
fi

sudo tee /etc/nginx/sites-available/default >/dev/null <<'EOF'
server {
	listen 80 default_server;
	listen [::]:80 default_server;

	server_name _;

	root /mnt/efs-psnd/content/frontend;
	index index.html;

	location / {
		try_files $uri $uri/ /index.html;
	}
}
EOF

if ! mountpoint -q /mnt/efs-psnd; then
	sudo mkdir -p /mnt/efs-psnd/content/frontend
	sudo cp /var/www/html/index.html /mnt/efs-psnd/content/frontend/index.html
fi

sudo chown -R www-data:www-data /mnt/efs-psnd/content/frontend || true
sudo chmod -R 755 /mnt/efs-psnd/content/frontend || true

sudo nginx -t

sudo systemctl restart nginx
