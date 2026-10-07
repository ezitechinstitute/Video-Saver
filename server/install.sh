#!/usr/bin/env bash
#
# Builds the Video Saver download server from nothing on a fresh Ubuntu 24.04
# box, in about ten minutes. Run it as root on the new machine:
#
#     curl -fsSL https://raw.githubusercontent.com/ezitechinstitute/Video-Saver/main/server/install.sh | bash
#
# There is no state worth backing up here: downloads are temporary files and
# the database only records them. Losing the machine costs the time below,
# nothing else.
#
# One thing matters when picking the machine: NOT India. TikTok is blocked
# there, so a Bangalore droplet serves an empty page and no TikTok link can be
# read. Singapore works and is close to Pakistan.

set -euo pipefail

REPO=https://github.com/ezitechinstitute/ezi-downloadapp.git
APP=/var/www/ezisaver
DOMAIN=${DOMAIN:-ezisaver.ezitech.org}

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }

say "Checking the machine is not in a country that blocks TikTok"
COUNTRY=$(curl -fsS --max-time 15 https://ipinfo.io/country 2>/dev/null | tr -d '[:space:]' || echo "?")
if [ "$COUNTRY" = "IN" ]; then
    echo "This machine is in India, where TikTok is blocked. TikTok links will" >&2
    echo "never work from here. Rebuild in Singapore (sgp1) instead." >&2
    exit 1
fi
echo "Region: ${COUNTRY:-unknown} — fine."

say "Swap (the 512MB plan runs out of memory during composer install)"
if [ ! -f /swapfile ]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

say "System packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq software-properties-common curl git unzip nginx ffmpeg python3

say "PHP 8.4 (the lock file needs it; Ubuntu 24.04 ships 8.3)"
add-apt-repository -y ppa:ondrej/php >/dev/null
apt-get update -qq
apt-get install -y -qq php8.4-fpm php8.4-cli php8.4-sqlite3 php8.4-mbstring \
    php8.4-xml php8.4-curl php8.4-zip php8.4-bcmath

say "Composer"
if [ ! -x /usr/local/bin/composer ]; then
    curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php
    php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
    rm -f /tmp/composer-setup.php
fi

say "The application"
if [ -d "$APP/.git" ]; then
    git -C "$APP" pull --ff-only
else
    rm -rf "$APP"
    git clone --depth 1 "$REPO" "$APP"
fi
cd "$APP"
composer install --no-dev --optimize-autoloader --no-interaction

say "Configuration"
if [ ! -f .env ]; then
    cp .env.example .env
    sed -i "s|^APP_ENV=.*|APP_ENV=production|"               .env
    sed -i "s|^APP_DEBUG=.*|APP_DEBUG=false|"                 .env
    sed -i "s|^APP_URL=.*|APP_URL=https://$DOMAIN|"           .env
    sed -i "s|^QUEUE_CONNECTION=.*|QUEUE_CONNECTION=database|" .env
    php artisan key:generate --force
fi
touch database/database.sqlite
php artisan migrate --force
php artisan storage:link || true
php artisan config:cache

# yt-dlp_linux, not the plain yt-dlp: TikTok only answers a request that looks
# like a real browser's, and only this build carries the curl_cffi impersonation
# it needs. The plain build fails on every TikTok link, with an error that says
# nothing about why.
say "yt-dlp (nightly linux build: the sites change faster than stable releases)"
mkdir -p storage/app/bin
curl -fsSL https://github.com/yt-dlp/yt-dlp-nightly-builds/releases/latest/download/yt-dlp_linux \
    -o storage/app/bin/yt-dlp.exe
chmod +x storage/app/bin/yt-dlp.exe
storage/app/bin/yt-dlp.exe --version
storage/app/bin/yt-dlp.exe --list-impersonate-targets | head -3

chown -R www-data:www-data "$APP"
chmod -R ug+rwX storage bootstrap/cache

say "nginx"
cat > /etc/nginx/sites-available/ezisaver <<NGINX
server {
    listen 80;
    server_name $DOMAIN _;
    root $APP/public;
    index index.php;

    # Videos can be tens of MB and take a while on a slow phone connection.
    client_max_body_size 64M;
    sendfile on;

    location / { try_files \$uri \$uri/ /index.php?\$query_string; }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
        fastcgi_read_timeout 300;
    }

    location ~ /\.(?!well-known).* { deny all; }
}
NGINX
ln -sf /etc/nginx/sites-available/ezisaver /etc/nginx/sites-enabled/ezisaver
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

say "Queue worker (one download at a time, which is all 512MB allows)"
cat > /etc/systemd/system/ezisaver-worker.service <<UNIT
[Unit]
Description=EziSaver queue worker (runs yt-dlp for each download)
After=network.target

[Service]
User=www-data
Group=www-data
Restart=always
RestartSec=5
WorkingDirectory=$APP
ExecStart=/usr/bin/php artisan queue:work --sleep=2 --tries=2 --timeout=600

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now ezisaver-worker
systemctl restart ezisaver-worker

say "Nightly yt-dlp update (sites break it every few weeks)"
cat > /etc/cron.weekly/ezisaver-ytdlp <<CRON
#!/bin/sh
curl -fsSL https://github.com/yt-dlp/yt-dlp-nightly-builds/releases/latest/download/yt-dlp_linux \
    -o $APP/storage/app/bin/yt-dlp.exe.new \
  && chmod +x $APP/storage/app/bin/yt-dlp.exe.new \
  && mv $APP/storage/app/bin/yt-dlp.exe.new $APP/storage/app/bin/yt-dlp.exe
CRON
chmod +x /etc/cron.weekly/ezisaver-ytdlp

say "Clear out finished downloads daily (10GB disk fills up otherwise)"
cat > /etc/cron.daily/ezisaver-cleanup <<CRON
#!/bin/sh
find $APP/storage/app/public/downloads -type f -mtime +1 -delete 2>/dev/null
CRON
chmod +x /etc/cron.daily/ezisaver-cleanup

say "Done"
echo "API:  http://$(curl -fsS --max-time 10 ifconfig.me || echo "<this machine>")/api/downloads"
echo
echo "Still to do by hand:"
echo "  1. Point $DOMAIN at this machine's IP (DNS lives at GreenGeeks)."
echo "  2. Once DNS has moved:  certbot --nginx -d $DOMAIN"
echo "     (apt-get install -y certbot python3-certbot-nginx)"
