#!/bin/bash

# Configuration
LOG_FILE="/var/log/sys_monitor.log"
THRESHOLD_CPU=3
BOT_TOKEN="7756648526:AAGgP5pXQuhhyg5gqz83WBbp2ScvUH0wrrI"
CHAT_ID="1276767407"
TELEGRAM_API="https://api.telegram.org/bot$BOT_TOKEN/sendMessage"
REFRESH_RATE=5  # seconds

# Initialize log file if not exists
[ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"

# Function to log system data
log_system_data() {
    echo "$(date) - Collecting system stats..." >> "$LOG_FILE"
    echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4"%"}')" >> "$LOG_FILE"
    echo "Memory Usage: $(free -m | awk 'NR==2{printf "Memory: %s/%sMB (%.2f%%)\n", $3, $2, $3*100/$2 }')" >> "$LOG_FILE"
    echo "Disk Usage: $(df -h / | awk 'NR==2 {print $5}')" >> "$LOG_FILE"
    echo "Active Connections: $(ss -tulnp | wc -l)" >> "$LOG_FILE"
}

# Function to send Telegram alert
send_telegram_alert() {
    local message="⚠️ *System Alert*%0A$(date)%0A%0A$1"
    curl -s -X POST "$TELEGRAM_API" -d chat_id="$CHAT_ID" -d text="$message" -d parse_mode="Markdown" >/dev/null
}

# Function to check CPU and send alert if needed
check_cpu_alert() {
    local CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    if (( $(echo "$CPU_LOAD > $THRESHOLD_CPU" | bc -l) )); then
        send_telegram_alert "🚨 High CPU Usage Detected: $CPU_LOAD% (Threshold: $THRESHOLD_CPU%)"
    fi
}

# Function to display system stats in whiptail
display_stats() {
    while true; do
        # Get system stats
        CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2 + $4)}')
        MEM_TOTAL=$(free -m | awk 'NR==2{print $2}')
        MEM_USED=$(free -m | awk 'NR==2{print $3}')
        MEM_PERCENT=$(( 100 * MEM_USED / MEM_TOTAL ))
        DISK=$(df -h / | awk 'NR==2 {print $5}')
        NET=$(ss -s | grep "estab" | awk '{print $4}')
        TEMP=$(sensors | grep "Core 0" | awk '{print $3}' 2>/dev/null || echo "N/A")
        DISK_IO=$(iostat -d | awk 'NR==4 {print $2}' 2>/dev/null || echo "N/A")
        
        # Get top processes
        TOP_CPU=$(ps -eo pid,user,%cpu,comm --sort=-%cpu | head -6 | awk '{printf "%-8s %-10s %-5s %s\n", $1, $2, $3, $4}' | tr '\n' '|')
        TOP_MEM=$(ps -eo pid,user,%mem,comm --sort=-%mem | head -6 | awk '{printf "%-8s %-10s %-5s %s\n", $1, $2, $3, $4}' | tr '\n' '|')
        
        # Create whiptail menu
        choice=$(whiptail --title "🖥️ SYSTEM MONITOR DASHBOARD" --menu "\
CPU Usage: $CPU% | Memory: $MEM_USED/$MEM_TOTAL MB ($MEM_PERCENT%) | Disk: $DISK
Network: $NET conn | Temp: $TEMP | Disk I/O: $DISK_IO MB/s

Top CPU Processes:
PID     USER       %CPU  COMMAND
$(echo "$TOP_CPU" | tr '|' '\n')

Top Memory Processes:
PID     USER       %MEM  COMMAND
$(echo "$TOP_MEM" | tr '|' '\n')" 30 90 6 \
"1" "Refresh (Every $REFRESH_RATE sec)" \
"2" "Kill a Process" \
"3" "Monitor Network Bandwidth" \
"4" "Run Auto-Healing" \
"5" "View Logs" \
"6" "Exit" 3>&1 1>&2 2>&3)
        
        # Check CPU threshold in background
        check_cpu_alert &
        
        case $choice in
            1) sleep "$REFRESH_RATE" ;;
            2) kill_process ;;
            3) monitor_network ;;
            4) auto_heal ;;
            5) show_logs ;;
            6) break ;;
            *) break ;;
        esac
    done
}

# Function to kill a process
kill_process() {
    PID=$(whiptail --inputbox "Enter PID to kill:" 8 78 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus -ne 0 ] || [ -z "$PID" ]; then
        whiptail --msgbox "Operation cancelled or no PID entered!" 8 40
        return
    fi
    
    if ps -p "$PID" > /dev/null; then
        kill -9 "$PID"
        whiptail --msgbox "✅ Process $PID killed!" 8 40
        send_telegram_alert "Process $PID was killed by the system monitor"
    else
        whiptail --msgbox "❌ Process $PID not found!" 8 40
    fi
}

# Function to monitor network bandwidth
monitor_network() {
    whiptail --title "🌐 Network Bandwidth Monitoring" --msgbox "Starting network monitor for 10 seconds..." 8 50
    timeout 10 ifstat -i eth0 -b -n 1 > /tmp/network_stats.txt
    whiptail --title "🌐 Network Bandwidth Results" --textbox /tmp/network_stats.txt 20 90
    rm /tmp/network_stats.txt
}

# Function for auto-healing
auto_heal() {
    log_system_data
    healing_msg="🔍 Running System Health Check...\n"
    
    # Check CPU
    CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    if (( $(echo "$CPU_LOAD > $THRESHOLD_CPU" | bc -l) )); then
        PID=$(ps -eo pid,%cpu --sort=-%cpu | awk 'NR==2 {print $1}')
        healing_msg+="⚠️ High CPU detected! Killing process $PID...\n"
        kill -9 "$PID"
        send_telegram_alert "High CPU usage detected ($CPU_LOAD%). Process $PID was killed."
    fi
    
    # Check Memory
    MEM_PERCENT=$(free | awk 'NR==2{print $3/$2 * 100.0}')
    if (( $(echo "$MEM_PERCENT > 80" | bc -l) )); then
        PID=$(ps -eo pid,%mem --sort=-%mem | awk 'NR==2 {print $1}')
        healing_msg+="⚠️ High Memory detected! Killing process $PID...\n"
        kill -9 "$PID"
        send_telegram_alert "High memory usage detected ($MEM_PERCENT%). Process $PID was killed."
    fi
    
    # Check Disk
    DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
    if [ "$DISK_USAGE" -gt 80 ]; then
        healing_msg+="⚠️ High Disk usage detected! ($DISK_USAGE%)\n"
        send_telegram_alert "High disk usage detected ($DISK_USAGE%)"
    fi
    
    healing_msg+="✅ Health check completed!"
    whiptail --title "Auto-Healing Results" --msgbox "$healing_msg" 20 60
}

# Function to show logs with working OK button
show_logs() {
    # Create a temporary file with the log content
    log_content=$(cat "$LOG_FILE")
    whiptail --title "📜 System Monitor Logs" --scrolltext --msgbox "$log_content" 25 90
}

# Main execution
while true; do
    display_stats
    if whiptail --title "Exit" --yesno "Are you sure you want to exit the system monitor?" 8 78; then
        whiptail --msgbox "Thank you for using the System Monitor!" 8 50
        break
    fi
done
