#!/bin/bash

# Install necessary tools (excluding PHP, Nginx, and RDS-related databases)
echo "Checking and installing necessary utilities..."
REQUIRED_PACKAGES=(net-tools sysstat ufw iproute2 curl)
for package in "${REQUIRED_PACKAGES[@]}"; do
    if ! dpkg -l | grep -qw "$package"; then
        echo "Installing $package..."
        sudo apt update && sudo apt install -y "$package"
    else
        echo "$package is already installed."
    fi
done

# Function to check if a service is running
check_service() {
    systemctl is-active --quiet "$1"
    if [ $? -eq 0 ]; then
        echo "[OK] $1 is running."
    else
        echo "[ERROR] $1 is not running! Consider restarting: systemctl restart $1"
    fi
}

# Check services
check_service nginx
check_service php-fpm

# Check nginx configuration
nginx -t 2>&1 | tee /tmp/nginx_test.log
if grep -q "test is successful" /tmp/nginx_test.log; then
    echo "[OK] Nginx configuration is valid."
else
    echo "[ERROR] Nginx configuration is invalid! Check /tmp/nginx_test.log"
fi

# Check logs for errors (last 20 lines)
echo "Checking logs for errors..."
echo "Nginx error log:"
tail -n 20 /var/log/nginx/error.log | grep -i "error"

echo "PHP-FPM error log:"
tail -n 20 /var/log/php-fpm.log | grep -i "error"

echo "System logs related to nginx/php:"
journalctl -u nginx -u php-fpm --since "1 hour ago" | grep -i "error"

# Check for excessive log files
echo "Checking for excessive log file sizes..."
du -sh /var/log/nginx/*.log /var/log/php*.log 2>/dev/null | sort -hr | head -n 5

# Check CPU, RAM, and IO utilization
echo "Checking system resources..."
top -b -n 1 | head -n 20
echo "Disk Usage:"
df -h
echo "IO Usage:"
iostat -xm 1 3

# Check permissions on index.php
if [ -f /var/www/html/index.php ]; then
    ls -lah /var/www/html/index.php
    if [ ! -r /var/www/html/index.php ]; then
        echo "[ERROR] index.php is not readable. Run: chmod 644 /var/www/html/index.php"
    fi
else
    echo "[ERROR] index.php not found!"
fi

# Check for port conflicts
ss -tulnp | grep -E '(:80|:443)'
if netstat -tulnp | grep -E '(:80|:443)' | grep -v nginx; then
    echo "[WARNING] Another process is using ports 80/443! Check netstat output."
fi

# Check for network issues using ss
echo "Checking network connections..."
ss -tulwn | grep -E '(:80|:443)'

# Check what port Nginx is set to
echo "Checking Nginx listen ports..."
grep -E "listen [0-9]+" /etc/nginx/sites-enabled/* /etc/nginx/nginx.conf 2>/dev/null

# Test web server availability using curl
echo "Testing HTTP and HTTPS responses..."
curl -I http://localhost 2>/dev/null | head -n 1
curl -I https://localhost --insecure 2>/dev/null | head -n 1

# Check firewall rules
if sudo ufw status | grep -q "80.*ALLOW" && sudo ufw status | grep -q "443.*ALLOW"; then
    echo "[OK] Firewall allows HTTP/HTTPS."
else
    echo "[ERROR] Firewall may be blocking HTTP/HTTPS. Run: sudo ufw allow 80/tcp && sudo ufw allow 443/tcp"
fi

# Check PHP-FPM pool configuration
if grep -q "listen = 127.0.0.1:9000" /etc/php/*/fpm/pool.d/www.conf; then
    echo "[OK] PHP-FPM is configured to listen on 127.0.0.1:9000."
else
    echo "[WARNING] PHP-FPM may be misconfigured. Check /etc/php/*/fpm/pool.d/www.conf"
fi

# Summary message
echo "PHP Server Troubleshooting completed. Check above logs for errors."
