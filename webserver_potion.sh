#!/bin/bash
# run as sudo
echo "Running as sudo input password if you have one"
sudo su

# Log file
LOG_FILE="/tmp/webserver_potion.log"
echo "Web Server Troubleshooting Report - $(date)" > $LOG_FILE

# Function to add a separator
add_separator() {
    echo "============================================================" | tee -a $LOG_FILE
}

# Install necessary tools (excluding PHP, Nginx, and RDS-related databases)
add_separator
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
add_separator
echo "Checking services..." | tee -a $LOG_FILE
check_service nginx
check_service php-fpm

# Check nginx configuration
add_separator
echo "Checking nginx configuration..." | tee -a $LOG_FILE
nginx -t 2>&1 | tee /tmp/nginx_test.log
if grep -q "test is successful" /tmp/nginx_test.log; then
    echo "[OK] Nginx configuration is valid." | tee -a $LOG_FILE
else
    echo "[ERROR] Nginx configuration is invalid! Check /tmp/nginx_test.log" | tee -a $LOG_FILE
fi

# Check logs for errors (last 20 lines)
add_separator
echo "Checking logs for errors..." | tee -a $LOG_FILE
echo "Nginx error log:" | tee -a $LOG_FILE
tail -n 20 /var/log/nginx/error.log | grep -i "error" | tee -a $LOG_FILE

echo "PHP-FPM error log:" | tee -a $LOG_FILE
tail -n 20 /var/log/php-fpm.log | grep -i "error" | tee -a $LOG_FILE

echo "System logs related to nginx/php:" | tee -a $LOG_FILE
journalctl -u nginx -u php-fpm --since "1 hour ago" | grep -i "error" | tee -a $LOG_FILE

# Check for excessive log files
add_separator
echo "Checking for excessive log file sizes..." | tee -a $LOG_FILE
du -sh /var/log/nginx/*.log /var/log/php*.log 2>/dev/null | sort -hr | head -n 5 | tee -a $LOG_FILE

# Check CPU, RAM, and IO utilization
add_separator
echo "Checking system resources..." | tee -a $LOG_FILE
top -b -n 1 | head -n 20 | tee -a $LOG_FILE
echo "Disk Usage:" | tee -a $LOG_FILE
df -h | tee -a $LOG_FILE
echo "IO Usage:" | tee -a $LOG_FILE
iostat -xm 1 3 | tee -a $LOG_FILE

# Check permissions on index.php
add_separator
echo "Checking permissions on index.php..." | tee -a $LOG_FILE
if [ -f /var/www/html/index.php ]; then
    ls -lah /var/www/html/index.php | tee -a $LOG_FILE
    if [ ! -r /var/www/html/index.php ]; then
        echo "[ERROR] index.php is not readable. Run: chmod 644 /var/www/html/index.php" | tee -a $LOG_FILE
    fi
else
    echo "[ERROR] index.php not found!" | tee -a $LOG_FILE
fi

# Test for Misconfigured .htaccess files can cause a 404 error:
add_separator
echo "Checking for misconfigured .htaccess files..." | tee -a $LOG_FILE
find /var/www/html -type f -name ".htaccess" -exec grep -H "RewriteRule" {} \; | tee -a $LOG_FILE

# Check for port conflicts
add_separator
echo "Checking for port conflicts..." | tee -a $LOG_FILE
ss -tulnp | grep -E '(:80|:443)' | tee -a $LOG_FILE
if netstat -tulnp | grep -E '(:80|:443)' | grep -v nginx; then
    echo "[WARNING] Another process is using ports 80/443! Check netstat output." | tee -a $LOG_FILE
fi

# Check for network issues using ss
add_separator
echo "Checking network connections..." | tee -a $LOG_FILE
ss -tulwn | grep -E '(:80|:443)' | tee -a $LOG_FILE

# Check what port Nginx is set to
add_separator
echo "Checking Nginx listen ports..." | tee -a $LOG_FILE
grep -E "listen [0-9]+" /etc/nginx/sites-enabled/* /etc/nginx/nginx.conf 2>/dev/null | tee -a $LOG_FILE

# Test web server availability using curl
add_separator
echo "Testing HTTP and HTTPS responses..." | tee -a $LOG_FILE
curl -I http://localhost 2>/dev/null | head -n 1 | tee -a $LOG_FILE
curl -I https://localhost --insecure 2>/dev/null | head -n 1 | tee -a $LOG_FILE

# Check firewall rules
add_separator
echo "Checking firewall rules..." | tee -a $LOG_FILE
if sudo ufw status | grep -q "80.*ALLOW" && sudo ufw status | grep -q "443.*ALLOW"; then
    echo "[OK] Firewall allows HTTP/HTTPS." | tee -a $LOG_FILE
else
    echo "[ERROR] Firewall may be blocking HTTP/HTTPS. Run: sudo ufw allow 80/tcp && sudo ufw allow 443/tcp" | tee -a $LOG_FILE
fi

# Check PHP-FPM pool configuration
add_separator
echo "Checking PHP-FPM pool configuration..." | tee -a $LOG_FILE
if grep -q "listen = 127.0.0.1:9000" /etc/php/*/fpm/pool.d/www.conf; then
    echo "[OK] PHP-FPM is configured to listen on 127.0.0.1:9000." | tee -a $LOG_FILE
else
    echo "[WARNING] PHP-FPM may be misconfigured. Check /etc/php/*/fpm/pool.d/www.conf" | tee -a $LOG_FILE
fi

# apache is returning a 404 error how would you fix.
# Check apache2 service status
add_separator
echo "Checking apache2 service status..." | tee -a $LOG_FILE
check_service apache2

# Check apache2 error log
add_separator
echo "Checking apache2 error log..." | tee -a $LOG_FILE
if [ -f /var/log/apache2/error.log ]; then
    tail -n 20 /var/log/apache2/error.log | tee -a $LOG_FILE
else
    echo "[ERROR] Apache2 error log not found!" | tee -a $LOG_FILE
fi

# Check apache2 access log
add_separator
echo "Checking apache2 access log..." | tee -a $LOG_FILE
if [ -f /var/log/apache2/access.log ]; then
    tail -n 20 /var/log/apache2/access.log | tee -a $LOG_FILE
else
    echo "[ERROR] Apache2 access log not found!" | tee -a $LOG_FILE
fi

# Check apache2 virtual host configuration and check syntax
add_separator
echo "Checking apache2 virtual host configuration..." | tee -a $LOG_FILE
if [ -d /etc/apache2/sites-available ]; then
    grep -r "DocumentRoot" /etc/apache2/sites-available/* | tee -a $LOG_FILE
    echo "Checking apache2 virtual host configuration syntax..." | tee -a $LOG_FILE
    apache2ctl configtest | tee -a $LOG_FILE
else
    echo "[ERROR] Apache2 virtual host configuration not found!" | tee -a $LOG_FILE
fi


# Check apache2 ports configuration
add_separator
echo "Checking apache2 ports configuration..." | tee -a $LOG_FILE
if [ -f /etc/apache2/ports.conf ]; then
    cat /etc/apache2/ports.conf | tee -a $LOG_FILE
else
    echo "[ERROR] Apache2 ports configuration not found!" | tee -a $LOG_FILE
fi


# Check apache2 sites-enabled configuration
add_separator
echo "Checking apache2 sites-enabled configuration..." | tee -a $LOG_FILE
if [ -d /etc/apache2/sites-enabled ]; then
    ls -l /etc/apache2/sites-enabled/ | tee -a $LOG_FILE
else
    echo "[ERROR] Apache2 sites-enabled configuration not found!" | tee -a $LOG_FILE
fi

# Check apache2 modules
add_separator
echo "Checking apache2 modules..." | tee -a $LOG_FILE
apache2ctl -M | tee -a $LOG_FILE

# Check apache2.conf file
add_separator
echo "Checking apache2.conf file..." | tee -a $LOG_FILE
if [ -f /etc/apache2/apache2.conf ]; then
    cat /etc/apache2/apache2.conf | tee -a $LOG_FILE
else
    echo "[ERROR] apache2.conf not found!" | tee -a $LOG_FILE
fi

# Check apache2 version
add_separator
echo "Checking apache2 version..." | tee -a $LOG_FILE
apache2 -v | tee -a $LOG_FILE

# Check apache2 permissions on index.html
add_separator
echo "Checking permissions on index.html..." | tee -a $LOG_FILE
if [ -f /var/www/html/index.html ]; then
    ls -lah /var/www/html/index.html | tee -a $LOG_FILE
    if [ ! -r /var/www/html/index.html ]; then
        echo "[ERROR] index.html is not readable. Run: chmod 644 /var/www/html/index.html" | tee -a $LOG_FILE
    fi
else
    echo "[ERROR] index.html not found!" | tee -a $LOG_FILE
fi

# Check apache2 permissions on directory /var/www/html
add_separator
echo "Checking permissions on /var/www/html directory..." | tee -a $LOG_FILE
if [ -d /var/www/html ]; then
    ls -lah /var/www/html | tee -a $LOG_FILE
    if [ ! -r /var/www/html ]; then
        echo "[ERROR] /var/www/html is not readable. Run: chmod 755 /var/www/html" | tee -a $LOG_FILE
    fi
else
    echo "[ERROR] /var/www/html directory not found!" | tee -a $LOG_FILE
fi


# Summary message
add_separator
echo "PHP Server Troubleshooting completed. Check above logs for errors or /tmp/php_potion.log" | tee -a $LOG_FILE