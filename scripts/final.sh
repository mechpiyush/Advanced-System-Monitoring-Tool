#!/bin/bash

# Configuration
LOG_FILE="/var/log/sys_monitor.log"
THRESHOLD_CPU=80
THRESHOLD_MEM=80
THRESHOLD_DISK=80
BOT_TOKEN="7756648526:AAGgP5pXQuhhyg5gqz83WBbp2ScvUH0wrrI"
CHAT_ID="1276767407"
TELEGRAM_API="https://api.telegram.org/bot$BOT_TOKEN/sendMessage"
EMAIL_RECIPIENT="admin@example.com"

# Function to log system data
log_system_data() {
    echo "$(date) - Collecting system stats..." >> $LOG_FILE
    echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4"%"}')" >> $LOG_FILE
    echo "Memory Usage: $(free -m | awk 'NR==2{printf "Memory: %s/%sMB (%.2f%%)\n", $3, $2, $3*100/$2 }')" >> $LOG_FILE
    echo "Disk Usage: $(df -h / | awk 'NR==2 {print $5}')" >> $LOG_FILE
    echo "Active Connections: $(netstat -tulnp | wc -l)" >> $LOG_FILE
}

# Function to display system stats
display_stats() {
    clear
    box_width=59

    print_centered_line() {
        local text="$1"
        local padding=$(( (box_width - ${#text} - 4) / 2 ))
        printf "\033[1;32m║%${padding}s %s %${padding}s║\033[0m\n" "" "$text" ""
    }

    echo -e "\033[1;32m╔$(printf '═%.0s' $(seq 1 $box_width))╗\033[0m"
    print_centered_line "🖥️  SYSTEM MONITOR DASHBOARD"
    echo -e "\033[1;32m╠$(printf '═%.0s' $(seq 1 $box_width))╣\033[0m"

    # CPU Usage
    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2 + $4)}')
    cpu_line="🔥 CPU Usage: ${CPU}%"
    printf "\033[1;34m║ %-$(($box_width - 4))s ║\033[0m\n" "$cpu_line"

    # Memory Usage
    MEM_TOTAL=$(free -m | awk 'NR==2{print $2}')
    MEM_USED=$(free -m | awk 'NR==2{print $3}')
    MEM_PERCENT=$(( 100 * MEM_USED / MEM_TOTAL ))
    mem_line="📌 Memory Usage: ${MEM_USED} MB / ${MEM_TOTAL} MB (${MEM_PERCENT}%)"
    printf "\033[1;34m║ %-$(($box_width - 4))s ║\033[0m\n" "$mem_line"

    # Disk Usage
    DISK=$(df -h / | awk 'NR==2 {print $5}')
    disk_line="💾 Disk Usage: ${DISK}"
    printf "\033[1;34m║ %-$(($box_width - 4))s ║\033[0m\n" "$disk_line"

    # Network Usage
    NET=$(ss -s | grep "estab" | awk '{print $4}')
    net_line="🌐 Active Connections: ${NET}"
    printf "\033[1;34m║ %-$(($box_width - 4))s ║\033[0m\n" "$net_line"

    # Temperature
    TEMP=$(sensors | grep "Core 0" | awk '{print $3}' 2>/dev/null || echo "N/A")
    temp_line="🌡️  CPU Temp: ${TEMP}"
    printf "\033[1;34m║ %-$(($box_width - 4))s ║\033[0m\n" "$temp_line"

    # Disk I/O
    DISK_IO=$(iostat -d | awk 'NR==4 {print $2}' 2>/dev/null || echo "N/A")
    disk_io_line="📊 Disk I/O: ${DISK_IO} MB/s"
    printf "\033[1;34m║ %-$(($box_width - 4))s ║\033[0m\n" "$disk_io_line"

    echo -e "\033[1;32m╚$(printf '═%.0s' $(seq 1 $box_width))╝\033[0m"
}

# Function to show top processes
show_processes() {
    echo -e "\n\033[1;36m📌 Top 5 CPU-consuming Processes\033[0m"
    ps -eo pid,user,%cpu,comm --sort=-%cpu | head -6 | column -t
    
    echo -e "\n\033[1;36m📌 Top 5 Memory-consuming Processes\033[0m"
    ps -eo pid,user,%mem,comm --sort=-%mem | head -6 | column -t
}

# Function to kill a process
kill_process() {
    echo -e "\n\033[1;31m⚠️  Killing High Resource Usage Process\033[0m"
    read -p "Enter PID to kill: " PID
    if ps -p $PID > /dev/null; then
        kill -9 $PID
        echo -e "✅ Process $PID killed!"
        send_alert "Process $PID was killed due to high resource usage"
    else
        echo -e "❌ Process $PID not found!"
    fi
    read -p "Press [Enter] to continue..."
}

# Function to monitor network bandwidth
monitor_network() {
    echo -e "\n\033[1;36m🌐 Live Network Bandwidth Usage (Press Ctrl+C to exit)\033[0m"
    ifstat -i eth0 -b -n 1
    read -p "Press [Enter] to continue..."
}

# Function for auto-healing
auto_heal() {
    echo -e "\n\033[1;35m🔍 Running System Health Check...\033[0m"
    
    # Check CPU
    CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    if (( $(echo "$CPU_LOAD > $THRESHOLD_CPU" | bc -l) )); then
        PID=$(ps -eo pid,%cpu --sort=-%cpu | awk 'NR==2 {print $1}')
        echo "⚠️ High CPU detected! Killing process $PID..."
        kill -9 $PID
        send_alert "High CPU usage detected ($CPU_LOAD%). Process $PID was killed."
    fi
    
    # Check Memory
    MEM_PERCENT=$(free | awk 'NR==2{print $3/$2 * 100.0}')
    if (( $(echo "$MEM_PERCENT > $THRESHOLD_MEM" | bc -l) )); then
        PID=$(ps -eo pid,%mem --sort=-%mem | awk 'NR==2 {print $1}')
        echo "⚠️ High Memory detected! Killing process $PID..."
        kill -9 $PID
        send_alert "High memory usage detected ($MEM_PERCENT%). Process $PID was killed."
    fi
    
    # Check Disk
    DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
    if [ "$DISK_USAGE" -gt "$THRESHOLD_DISK" ]; then
        echo "⚠️ High Disk usage detected! ($DISK_USAGE%)"
        send_alert "High disk usage detected ($DISK_USAGE%)"
    fi
    
    echo -e "✅ Health check completed!"
    read -p "Press [Enter] to continue..."
}

# Function to send alerts
send_alert() {
    local message="$1"
    local choice
    
    echo -e "\n\033[1;33m📢 Alert Options:\033[0m"
    echo "1. Send to Telegram"
    echo "2. Send as Email"
    echo "3. Both"
    echo "4. Cancel"
    read -p "Select alert method: " choice
    
    case $choice in
        1)
            send_telegram_alert "$message"
            ;;
        2)
            send_email_alert "$message"
            ;;
        3)
            send_telegram_alert "$message"
            send_email_alert "$message"
            ;;
        4)
            echo "Alert cancelled."
            ;;
        *)
            echo "Invalid option!"
            ;;
    esac
}

# Function to send Telegram alert
send_telegram_alert() {
    local message="⚠️ *System Alert*%0A$(date)%0A%0A$1"
    curl -s -X POST "$TELEGRAM_API" -d chat_id="$CHAT_ID" -d text="$message" -d parse_mode="Markdown" >/dev/null
    echo "✅ Telegram alert sent!"
}

# Function to send email alert
send_email_alert() {
    local subject="System Alert: $(date)"
    local body="$1"
    echo "$body" | mail -s "$subject" "$EMAIL_RECIPIENT"
    echo "✅ Email alert sent to $EMAIL_RECIPIENT!"
}

# Main menu
while true; do
    log_system_data
    display_stats
    show_processes
    
    echo -e "\n\033[1;33m📌 Main Menu:\033[0m"
    echo "1. Refresh"
    echo "2. Kill a Process"
    echo "3. Monitor Network Bandwidth"
    echo "4. Run Auto-Healing"
    echo "5. Send Custom Alert"
    echo "6. Exit"
    read -p "Select an option: " OPTION

    case $OPTION in
        1) continue ;;
        2) kill_process ;;
        3) monitor_network ;;
        4) auto_heal ;;
        5) read -p "Enter alert message: " msg; send_alert "$msg" ;;
        6) exit 0 ;;
        *) echo "Invalid option!"; sleep 1 ;;
    esac
done
