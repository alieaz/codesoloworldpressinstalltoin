#!/bin/bash

# ============================================
# CodeSolo Flash Screen
# ============================================

for i in {1..2}; do clear; sleep 0.15; done

cat << "EOF"

 ██████╗ ██████╗ ██████╗ ███████╗███████╗ ██████╗ ██╗      ██████╗ 
██╔════╝██╔═══██╗██╔══██╗██╔════╝██╔════╝██╔═══██╗██║     ██╔═══██╗
██║     ██║   ██║██║  ██║█████╗  ███████╗██║   ██║██║     ██║   ██║
██║     ██║   ██║██║  ██║██╔══╝  ╚════██║██║   ██║██║     ██║   ██║
╚██████╗╚██████╔╝██████╔╝███████╗███████║╚██████╔╝███████╗╚██████╔╝
 ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝╚══════╝ ╚═════╝ ╚══════╝ ╚═════╝ 

            C O D E S O L O   N E T W O R K
        WordPress One-Click Installer (Nginx)

EOF

sleep 1

# ============================================
# Fail Fast (Root Check)
# ============================================
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Please run as root (use sudo)."
  exit 1
fi

set -e

# ============================================
# User Input
# ============================================
read -p "Domain name (example.com): " DOMAIN
read -p "Database name: " DB_NAME
read -p "Database user: " DB_USER
read -s -p "Database password: " DB_PASS
echo
read -s -p "MySQL root password: " MYSQL_ROOT_PASS
echo

WEB_ROOT="/var/www/$DOMAIN"
PHP_VER="8.1"

# ============================================
# System Update & Packages
# ============================================
apt update -y
apt install -y nginx mysql-server unzip curl \
php$PHP_VER-fpm php$PHP_VER-mysql php$PHP_VER-curl \
php$PHP_VER-gd php$PHP_VER-mbstring php$PHP_VER-xml \
php$PHP_VER-zip

systemctl enable nginx mysql php$PHP_VER-fpm
systemctl start nginx mysql php$PHP_VER-fpm

# ============================================
# Database Setup
# ============================================
mysql -uroot -p"$MYSQL_ROOT_PASS" <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME DEFAULT CHARACTER SET utf8mb4;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# ============================================
# WordPress Install
# ============================================
mkdir -p $WEB_ROOT
cd /tmp
curl -fsSL https://wordpress.org/latest.zip -o wp.zip
unzip -oq wp.zip
cp -r wordpress/* $WEB_ROOT

chown -R www-data:www-data $WEB_ROOT
chmod -R 755 $WEB_ROOT

cp $WEB_ROOT/wp-config-sample.php $WEB_ROOT/wp-config.php
sed -i "s/database_name_here/$DB_NAME/" $WEB_ROOT/wp-config.php
sed -i "s/username_here/$DB_USER/" $WEB_ROOT/wp-config.php
sed -i "s/password_here/$DB_PASS/" $WEB_ROOT/wp-config.php

# ============================================
# Nginx Config
# ============================================
cat > /etc/nginx/sites-available/$DOMAIN <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    root $WEB_ROOT;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php$PHP_VER-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl reload nginx

# ============================================
# Finish Screen
# ============================================
clear
cat << EOF

============================================
 WordPress Installed Successfully
============================================
 Domain : http://$DOMAIN
 Webroot: $WEB_ROOT
 Server : Nginx + PHP $PHP_VER
============================================

EOF
