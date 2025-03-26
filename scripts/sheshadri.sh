#!/bin/bash

# Configuration
LOG_FILE="/var/log/sys_monitor.log"
THRESHOLD=85 # CPU threshold for alerts
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN}" # Environment variable for bot token
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID}"     # Environment variable for chat ID
TELEGRAM_API="https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"

# Function to log system stats
log_stats() {
    echo "$(date +'%Y-%m-%d %H:%M:%S.%3N') - Collecting system stats..." >> "$LOG_FILE"
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    MEM_USAGE=$(free -m | awk 'NR==2{printf "Memory: %s/%sMB (%.2f%%)\n", $3, $2, $3*100/$2 }')
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
    NET_CONNECTIONS=$(ss -s | grep "estab" | awk '{print $4}')

    echo "CPU Usage: $CPU_USAGE%" >> "$LOG_FILE"
    echo "$MEM_USAGE" >> "$LOG_FILE"
    echo "Disk Usage: $DISK_USAGE" >> "$LOG_FILE"
    echo "Active Connections: $NET_CONNECTIONS" >> "$LOG_FILE"
}

# Function to get system stats and render UI
get_stats() {
    clear
    echo -e "\033[1;32m╔═════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;32m║     🖥  ADVANCED SYSTEM MONITOR           ║\033[0m"
    echo -e "\033[1;32m╠═════════════════════════════════════════════════════╣\033[0m"

    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    MEM_TOTAL=$(free -m | awk 'NR==2{print $2}')
    MEM_USED=$(free -m | awk 'NR==2{print $3}')
    MEM_PERCENT=$(( 100 * MEM_USED / MEM_TOTAL ))
    DISK=$(df -h / | awk 'NR==2 {print $5}')
    NET=$(ss -s | grep "estab" | awk '{print $4}')
    TEMP=$(sensors | grep "Core 0" | awk '{print $3}') 2>/dev/null # Suppress errors if sensors not installed.
    DISK_IO=$(iostat -d | awk 'NR==4 {print $2}') 2>/dev/null # Suppress errors if iostat not installed.

    echo -e "\033[1;34m║ 🔥 CPU Usage: $CPU%                             ║\033[0m"
    echo -e "\033[1;34m║ 📌 Memory Usage: $MEM_USED MB / $MEM_TOTAL MB ($MEM_PERCENT%) ║\033[0m"
    echo -e "\033[1;34m║ 💾 Disk Usage: $DISK                           ║\033[0m"
    echo -e "\033[1;34m║ 🌐 Active Connections: $NET                      ║\033[0m"
    [ -n "$TEMP" ] && echo -e "\033[1;34m║ 🌡 CPU Temp: $TEMP                      ║\033[0m"
    [ -n "$DISK_IO" ] && echo -e "\033[1;34m║ 📊 Disk I/O: $DISK_IO MB/s              ║\033[0m"

    echo -e "\033[1;32m╚═════════════════════════════════════════════════════╝\033[0m"
}

# Function to display top processes
show_processes() {
    echo -e "\n\033[1;36m📌 Top 5 CPU-consuming Processes\033[0m"
    ps -eo pid,comm,%cpu --sort=-%cpu | head -6

    echo -e "\n\033[1;36m📌 Top 5 Memory-consuming Processes\033[0m"
    ps -eo pid,comm,%mem --sort=-%mem | head -6
}

# Function to kill high CPU/memory processes
kill_process() {
    echo -e "\n\033[1;31m⚠  Killing High Resource Usage Process\033[0m"
    read -p "Enter PID to kill: " PID
    if [[ -n "$PID" && "$PID" =~ ^[0-9]+$ ]]; then
        if kill -9 "$PID"; then
            echo -e "✅ Process $PID killed!"
        else
            echo -e "❌ Failed to kill process $PID. Check if process exists."
        fi
    else
        echo -e "❌ Invalid PID. Please enter a number."
    fi
}

# Function to monitor network bandwidth
monitor_network() {
    echo -e "\n\033[1;36m🌐 Live Network Bandwidth Usage\033[0m"
    watch -n 1 ifstat
}

# Function to send alerts
send_alert() {
    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    if (( $(echo "$CPU > $THRESHOLD" | bc -l) )); then
        MESSAGE="⚠ High CPU Usage Alert!%0A🔥 CPU Usage: $CPU%%"
        if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ] ; then
           curl -s -X POST "$TELEGRAM_API" -d chat_id="$TELEGRAM_CHAT_ID" -d text="$MESSAGE" -d parse_mode="Markdown"
        else
            echo "Telegram Bot Token or Chat ID not set. Alerts disabled."
        fi
    fi
}

# Main menu
while true; do
    get_stats
    show_processes
    echo -e "\n\033[1;33m📌 Options:\033[0m"
    echo -e "1️⃣  Refresh"
    echo -e "2️⃣  Kill a Process"
    echo -e "3️⃣  Monitor Network Bandwidth"
    echo -e "4️⃣  Toggle Logging (Currently: ${LOGGING_ENABLED:-Disabled})"
    echo -e "5️⃣  Exit"
    read -p "👉 Select an option: " OPTION

    case $OPTION in
        1) continue ;;
        2) kill_process ;;
        3) monitor_network ;;
        4)
          if [ -z "$LOGGING_ENABLED" ]; then
            LOGGING_ENABLED=Enabled
            echo "Logging Enabled"
          else
            unset LOGGING_ENABLED
            echo "Logging Disabled"
          fi
          ;;
        5) exit ;;
        *) echo "Invalid choice!";;
    esac

    if [ -n "$LOGGING_ENABLED" ]; then
        log_stats
    fi
    send_alert
done
