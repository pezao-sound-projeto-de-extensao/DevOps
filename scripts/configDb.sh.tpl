#!/bin/bash

sleep 100
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y mysql-server

systemctl enable mysql
systemctl restart mysql

cat > /tmp/initdb.sql <<'EOF'
${initdb_sql}
EOF

mysql < /tmp/initdb.sql