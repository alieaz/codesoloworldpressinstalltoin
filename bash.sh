#!/usr/bin/env bash

# =========================================================
# CODESOLO WordPress One-Click Installer
# Shell-safe version (NO while / until / done)
# =========================================================

clear

cat << 'EOF'
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

# ---- Root check ----
if [ "$(id -u)" != "0" ]; then
  echo "ERROR: Run as root (sudo)"
  exit 1
fi

# =========================================================
# User Input (NO LOOPS)
# =========================================================

read -r -p "Domain name (example.com): " DOMAIN
[ -z "$DOMAIN" ] && echo "ERROR: Domain required" && exit 1

read -r -p "Database name: " DB_NAME
[ -z "$DB_NAME" ] && echo "ERROR: Database name required" && exit 1

read -r -p "Database user: " DB_USER
[ -z "$DB_USER" ] && echo "ERROR: Database user required" && exit 1

read -r -s -p "Database password: " DB_PASS
echo
[ -z "$DB_PASS" ] && echo "ERROR: Database password required" && exit 1

PHP_VER="8.2"
WEB_ROOT="/var/www/$DOMAIN"

# =========================================================
# Install packages
# =========================================================

apt update -y
apt install -y nginx mariadb-server unzip curl \
php$PHP_VER-fpm php$PHP_VER-mysql php$PHP_VER-curl \
php$PHP_VER-gd php$PHP_VER-mbstring php$PHP_VER-xml \
php$PHP_VER-zip

systemctl enable nginx mariadb php$PHP_VER-fpm
systemctl start nginx mariadb php$PHP_VER-fpm

# =========================================================
# Database
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
# WordPress
# =========================================================

mkdir -p "$WEB_ROOT"
cd /tmp || exit 1

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
# Nginx
# =========================================================

cat > "/etc/nginx/sites-available/$DOMAIN" <<EOF
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

ln -sf "/etc/nginx/sites-available/$DOMAIN" /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl reload nginx

# =========================================================
# Done
# =========================================================

clear
echo "======================================"
echo " WordPress Installed Successfully"
echo " URL: http://$DOMAIN"
echo "======================================"
