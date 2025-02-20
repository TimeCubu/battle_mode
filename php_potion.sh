#!/bin/bash

# Log file
LOG_FILE="/tmp/php_potion.log"
echo "PHP Server Troubleshooting Report - $(date)" > $LOG_FILE

# Install necessary tools (excluding PHP, Nginx, and RDS-related databases)
echo "Checking and installing necessary utilities..." | tee -a $LOG_FILE
REQUIRED_PACKAGES=(net-tools sysstat ufw iproute2 curl)
for package in "${REQUIRED_PACKAGES[@]}"; do
    if ! dpkg -l | grep -qw "$package"; then
        echo "Installing $package..." | tee -a $LOG_FILE
        sudo apt update && sudo apt install -y "$package" | tee -a $LOG_FILE
    else
        echo "$package is already installed." | tee -a $LOG_FILE
    fi
done

# Function to check if a service is running
check_service() {
    systemctl is-active --quiet "$1"
    if [ $? -eq 0 ]; then
        echo "[OK] $1 is running." | tee -a $LOG_FILE
    else
        echo "[ERROR] $1 is not running! Consider restarting: systemctl restart $1" | tee -a $LOG_FILE
    fi
}

# Check services
check_service nginx
check_service php-fpm

# Check nginx configuration
nginx -t 2>&1 | tee /tmp/nginx_test.log
if grep -q "test is successful" /tmp/nginx_test.log; then
    echo "[OK] Nginx configuration is valid." | tee -a $LOG_FILE
else
    echo "[ERROR] Nginx configuration is invalid! Check /tmp/nginx_test.log" | tee -a $LOG_FILE
fi

# Check logs for errors (last 20 lines)
echo "Checking logs for errors..." | tee -a $LOG_FILE
echo "Nginx error log:" | tee -a $LOG_FILE
tail -n 20 /var/log/nginx/error.log | grep -i "error" | tee -a $LOG_FILE

echo "PHP-FPM error log:" | tee -a $LOG_FILE
tail -n 20 /var/log/php-fpm.log | grep -i "error" | tee -a $LOG_FILE

echo "System logs related to nginx/php:" | tee -a $LOG_FILE
journalctl -u nginx -u php-fpm --since "1 hour ago" | grep -i "error" | tee -a $LOG_FILE

# Check for excessive log files
echo "Checking for excessive log file sizes..." | tee -a $LOG_FILE
du -sh /var/log/nginx/*.log /var/log/php*.log 2>/dev/null | sort -hr | head -n 5 | tee -a $LOG_FILE

# Check CPU, RAM, and IO utilization
echo "Checking system resources..." | tee -a $LOG_FILE
top -b -n 1 | head -n 20 | tee -a $LOG_FILE
echo "Disk Usage:" | tee -a $LOG_FILE
df -h | tee -a $LOG_FILE
echo "IO Usage:" | tee -a $LOG_FILE
iostat -xm 1 3 | tee -a $LOG_FILE

# Check permissions on index.php
if [ -f /var/www/html/index.php ]; then
    ls -lah /var/www/html/index.php | tee -a $LOG_FILE
    if [ ! -r /var/www/html/index.php ]; then
        echo "[ERROR] index.php is not readable. Run: chmod 644 /var/www/html/index.php" | tee -a $LOG_FILE
    fi
else
    echo "[ERROR] index.php not found!" | tee -a $LOG_FILE
fi

# Check for port conflicts
ss -tulnp | grep -E '(:80|:443)' | tee -a $LOG_FILE
if netstat -tulnp | grep -E '(:80|:443)' | grep -v nginx; then
    echo "[WARNING] Another process is using ports 80/443! Check netstat output." | tee -a $LOG_FILE
fi

# Check for network issues using ss
echo "Checking network connections..." | tee -a $LOG_FILE
ss -tulwn | grep -E '(:80|:443)' | tee -a $LOG_FILE

# Check what port Nginx is set to
echo "Checking Nginx listen ports..." | tee -a $LOG_FILE
grep -E "listen [0-9]+" /etc/nginx/sites-enabled/* /etc/nginx/nginx.conf 2>/dev/null | tee -a $LOG_FILE

# Test web server availability using curl
echo "Testing HTTP and HTTPS responses..." | tee -a $LOG_FILE
curl -I http://localhost 2>/dev/null | head -n 1 | tee -a $LOG_FILE
curl -I https://localhost --insecure 2>/dev/null | head -n 1 | tee -a $LOG_FILE

# Check firewall rules
if sudo ufw status | grep -q "80.*ALLOW" && sudo ufw status | grep -q "443.*ALLOW"; then
    echo "[OK] Firewall allows HTTP/HTTPS." | tee -a $LOG_FILE
else
    echo "[ERROR] Firewall may be blocking HTTP/HTTPS. Run: sudo ufw allow 80/tcp && sudo ufw allow 443/tcp" | tee -a $LOG_FILE
fi

# Check PHP-FPM pool configuration
if grep -q "listen = 127.0.0.1:9000" /etc/php/*/fpm/pool.d/www.conf; then
    echo "[OK] PHP-FPM is configured to listen on 127.0.0.1:9000." | tee -a $LOG_FILE
else
    echo "[WARNING] PHP-FPM may be misconfigured. Check /etc/php/*/fpm/pool.d/www.conf" | tee -a $LOG_FILE
fi

# Summary message
echo "PHP Server Troubleshooting completed. Check above logs for errors." | tee -a $LOG_FILE