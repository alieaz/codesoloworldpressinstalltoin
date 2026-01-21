#!/bin/bash

# =========================================================
# CODESOLO WordPress One-Click Installer
# Stack: Nginx + PHP 8.2 + MariaDB
# =========================================================

# ---- Flash Screen ----
for i in 1 2; do clear; sleep 0.15; done

cat << "EOF"

╔═════════════════════════════════════════════════════════╗
║                                                         ║
║   ██████╗  ██████╗ ██████╗ ███████╗███████╗ ██████╗     ║
║  ██╔════╝ ██╔═══██╗██╔══██╗██╔════╝██╔════╝██╔═══██╗    ║
║  ██║      ██║   ██║██║  ██║█████╗  ███████╗██║   ██║    ║
║  ██║      ██║   ██║██║  ██║██╔══╝  ╚════██║██║   ██║    ║
║  ╚██████╗ ╚██████╔╝██████╔╝███████╗███████║╚██████╔╝    ║
║   ╚═════╝  ╚═════╝ ╚═════╝ ╚══════╝╚══════╝ ╚═════╝     ║
║                                                         ║
║                     C O D E S O L O                     ║
║                        N E T W O R K                    ║
║             WordPress One-Click Installer               ║
║                                                         ║
╚═════════════════════════════════════════════════════════╝

EOF

sleep 1

# ---- Root Check ----
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Run this installer as root (sudo)."
  exit 1
fi

set -e

# =========================================================
# User Input (FULL VALIDATION)
# =========================================================

while [[ -z "$DOMAIN" ]]; do
  read -p "Domain name (example.com): " DOMAIN
done

while [[ -z "$DB_NAME" ]]; do
  read -p "Database name (no spaces): " DB_NAME
done

while [[ -z "$DB_USER" ]]; do
  read -p "Database user: " DB_USER
done

while [[ -z "$DB_PASS" ]]; do
  read -s -p "Database password: " DB_PASS
  echo
done

WEB_ROOT="/var/www/$DOMAIN"
PHP_VER="8.2"

# =========================================================
# Install Packages
# =========================================================
apt update -y
apt install -y nginx mariadb-server unzip curl \
php$PHP_VER-fpm php$PHP_VER-mysql php$PHP_VER-curl \
php$PHP_VER-gd php$PHP_VER-mbstring php$PHP_VER-xml \
php$PHP_VER-zip

systemctl enable nginx mariadb php$PHP_VER-fpm
systemctl start nginx mariadb php$PHP_VER-fpm

# =========================================================
# Database Setup (MariaDB SAFE)
# =========================================================
mysql <<EOF
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '$DB_USER'@'localhost'
IDENTIFIED BY '$DB_PASS';

GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# =========================================================
# WordPress Install
# =========================================================
mkdir -p "$WEB_ROOT"
cd /tmp

curl -fsSL https://wordpress.org/latest.zip -o wp.zip
unzip -oq wp.zip
cp -r wordpress/* "$WEB_ROOT"

chown -R www-data:www-data "$WEB_ROOT"
chmod -R 755 "$WEB_ROOT"

cp "$WEB_ROOT/wp-config-sample.php" "$WEB_ROOT/wp-config.php"
sed -i "s/database_name_here/$DB_NAME/" "$WEB_ROOT/wp-config.php"
sed -i "s/username_here/$DB_USER/" "$WEB_ROOT/wp-config.php"
sed -i "s/password_here/$DB_PASS/" "$WEB_ROOT/wp-config.php"

# =========================================================
# Nginx Config
# =========================================================
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

# =========================================================
# Finish
# =========================================================
clear
cat << EOF

╔══════════════════════════════════════════════╗
║   WORDPRESS INSTALLED SUCCESSFULLY           ║
╠══════════════════════════════════════════════╣
║   URL     : http://$DOMAIN                   ║
║   Webroot : $WEB_ROOT                        ║
║   Stack   : Nginx + PHP $PHP_VER + MariaDB   ║
╚══════════════════════════════════════════════╝

EOF
