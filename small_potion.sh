#!/bin/bash

# Log file
LOG_FILE="/tmp/sysadmin_diagnosis.log"
echo "SysAdmin Troubleshooting Report - $(date)" > $LOG_FILE

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to check and install missing packages
install_if_missing() {
    if ! command_exists $1; then
        echo "$1 is not installed. Installing..." | tee -a $LOG_FILE
        sudo apt-get install -y $1 || sudo yum install -y $1
    fi
}

# Ensure required tools are installed
install_if_missing mpstat
install_if_missing iotop
install_if_missing ss


echo "==================== System Resource Usage ====================" >> $LOG_FILE
# CPU, Memory, Disk Usage
echo "CPU Usage:" >> $LOG_FILE
mpstat 1 5 | tail -n 10 >> $LOG_FILE

echo -e "\nMemory Usage:" >> $LOG_FILE
free -m >> $LOG_FILE

echo -e "\nDisk Usage:" >> $LOG_FILE
df -h >> $LOG_FILE

echo -e "\nI/O Usage:" >> $LOG_FILE
iotop -b -n 5 | head -n 20 >> $LOG_FILE

echo "==================== Running & Failed Services ====================" >> $LOG_FILE
# List all running & failed services
echo "Running Services:" >> $LOG_FILE
systemctl list-units --type=service --state=running >> $LOG_FILE

echo -e "\nFailed Services:" >> $LOG_FILE
systemctl list-units --failed >> $LOG_FILE


echo "==================== Network & Firewall ====================" >> $LOG_FILE
# Network Connections & Open Ports
echo "Listening Ports:" >> $LOG_FILE
ss -tulnp >> $LOG_FILE
# where are apache2 config files located
# /etc/apache2/apache2.conf
# /etc/apache2/sites-available/000-default.conf
# Check if apache2 is installed before running

# Check if iptables is installed before running
if command_exists iptables; then
    echo -e "\nFirewall Rules (iptables):" >> $LOG_FILE
    iptables -L -n -v >> $LOG_FILE
elif command_exists ufw; then
    echo -e "\nFirewall Rules (ufw):" >> $LOG_FILE
    ufw status verbose >> $LOG_FILE
else
    echo -e "\nFirewall rules check skipped (iptables and ufw not found)." >> $LOG_FILE
fi


echo "==================== Security Checks ====================" >> $LOG_FILE
# Failed SSH logins & open sessions
echo "Failed SSH Logins:" >> $LOG_FILE
if [ -f /var/log/auth.log ]; then
    grep "Failed password" /var/log/auth.log | tail -n 10 >> $LOG_FILE
elif [ -f /var/log/secure ]; then
    grep "Failed password" /var/log/secure | tail -n 10 >> $LOG_FILE
else
    echo "No authentication log found." >> $LOG_FILE
fi

echo -e "\nActive SSH Sessions:" >> $LOG_FILE
who >> $LOG_FILE


echo "==================== Logs & Errors ====================" >> $LOG_FILE
# Check if journalctl is installed before running
if command_exists journalctl; then
    echo -e "\nSystem Log Errors (journalctl):" >> $LOG_FILE
    journalctl -p 3 -n 20 >> $LOG_FILE
elif [ -f /var/log/syslog ]; then
    echo -e "\nSystem Log Errors (/var/log/syslog):" >> $LOG_FILE
    tail -n 20 /var/log/syslog >> $LOG_FILE
elif [ -f /var/log/messages ]; then
    echo -e "\nSystem Log Errors (/var/log/messages):" >> $LOG_FILE
    tail -n 20 /var/log/messages >> $LOG_FILE
else
    echo "No system logs found." >> $LOG_FILE
fi

echo "Report saved to $LOG_FILE"
cat $LOG_FILE
