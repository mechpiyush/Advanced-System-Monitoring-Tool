#!/bin/bash

# Configuration
LOG_FILE="/var/log/sys_monitor.log"
THRESHOLD_CPU=3
BOT_TOKEN="7756648526:AAGgP5pXQuhhyg5gqz83WBbp2ScvUH0wrrI"
CHAT_ID="1276767407"
TELEGRAM_API="https://api.telegram.org/bot$BOT_TOKEN/sendMessage"
REFRESH_RATE=1  # seconds for dashboard refresh
HEAL_INTERVAL=60  # seconds between auto-heal checks

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

# Function to send Telegram alert with last 5 log entries
send_telegram_alert() {
    local message="$1"
    # Get last 5 complete log records (5 entries × 5 lines each = 25 lines)
    local log_records=$(tail -n 25 "$LOG_FILE" | sed 's/%/%25/g' | sed ':a;N;$!ba;s/\n/%0A/g')
    local full_message="⚠ System Alert%0A$(date)%0A%0A${message}%0A%0ALast 5 log records:%0A${log_records}"
    curl -s -X POST "$TELEGRAM_API" -d chat_id="$CHAT_ID" -d text="$full_message" -d parse_mode="Markdown" >/dev/null
}

# Function to check CPU and send alert if needed
check_cpu_alert() {
    local CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    if (( $(echo "$CPU_LOAD > $THRESHOLD_CPU" | bc -l) )); then
        send_telegram_alert "🚨 High CPU Usage Detected"
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
        TOP_MEM=$(ps -eo pid,user,%mem,comm --sort=-%mem | head -6 | awk '{printf "%-8s %-10s %-5s %s\n", $1, $2, $3, $4}' | tr '\n' '|')

        # Create whiptail menu
        choice=$(whiptail --title "🖥  SYSTEM MONITOR DASHBOARD" --menu "\
CPU Usage: $CPU% | Memory: $MEM_USED/$MEM_TOTAL MB ($MEM_PERCENT%) | Disk: $DISK
Network: $NET conn | Disk I/O: $DISK_IO MB/s

Top Memory Processes:
PID     USER       %MEM  COMMAND
$(echo "$TOP_MEM" | tr '|' '\n')" 30 90 6 \
"1" "Refresh (Every $REFRESH_RATE sec)" \
"2" "Kill a Process" \
"3" "Monitor Network Bandwidth" \
"4" "Toggle Auto-Healing (CPU)" \
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
    PROCESS_LIST=$(ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | awk '{printf "%s \"%s (CPU: %s%%, MEM: %s%%)\"\n", $1, $5, $3, $4}' | head -n 15)
    SEARCH_TERM=$(whiptail --inputbox "Enter process name to search (leave empty for all):" 8 60 3>&1 1>&2 2>&3)

    if [ -n "$SEARCH_TERM" ]; then
        FILTERED_LIST=$(ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | grep -i "$SEARCH_TERM" | awk '{printf "%s \"%s (CPU: %s%%, MEM: %s%%)\"\n", $1, $5, $3, $4}' | head -n 10)
        [ -z "$FILTERED_LIST" ] && FILTERED_LIST="No_Process \"No matching processes found\""
    else
        FILTERED_LIST="$PROCESS_LIST"
    fi

    PID=$(whiptail --title "Select Process to Kill" --menu "Select a process to kill:" 20 80 10 $FILTERED_LIST 3>&1 1>&2 2>&3)
    [ -z "$PID" ] && return

    kill -9 "$PID"
    send_telegram_alert "Process $PID was killed by manual intervention"
    whiptail --msgbox "✅ Process $PID killed!" 8 40
}

# Function to monitor network bandwidth
monitor_network() {
    if ! command -v ifstat &> /dev/null; then
        whiptail --msgbox "❌ ifstat not found! Install with: sudo apt-get install ifstat" 12 60
        return 1
    fi

    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    [ -z "$INTERFACE" ] && INTERFACE="eth0"

    whiptail --title "🌐 Network Monitoring" --msgbox "Monitoring $INTERFACE for 10 seconds..." 10 60
    
    (
        echo "Timestamp         RX(Kbps)   TX(Kbps)"
        timeout 10 ifstat -i "$INTERFACE" -b -n 1 2>/dev/null | \
        while read -r rx tx; do
            [[ $rx =~ ^[0-9.]+$ ]] && [[ $tx =~ ^[0-9.]+$ ]] && \
            printf "%s %8.1f %11.1f\n" "$(date +'%H:%M:%S')" "$rx" "$tx"
        done
    ) > /tmp/network_stats.txt

    if [ -s /tmp/network_stats.txt ]; then
        whiptail --title "🌐 Network Results" --textbox /tmp/network_stats.txt 20 90
    else
        whiptail --msgbox "⚠ No network data collected!" 10 50
    fi
    rm -f /tmp/network_stats.txt
}

# Function to toggle auto-healing
auto_heal() {
    if [ -f "/tmp/auto_heal.pid" ]; then
        PID=$(cat /tmp/auto_heal.pid)
        if kill -0 "$PID" 2>/dev/null; then
            if whiptail --yesno "Auto-healing is active. Disable it?" 8 78; then
                kill "$PID"
                rm "/tmp/auto_heal.pid"
                whiptail --msgbox "Auto-healing disabled." 8 40
                send_telegram_alert "🛑 Auto-healing manually disabled"
            fi
            return
        else
            rm "/tmp/auto_heal.pid"
        fi
    fi

    if whiptail --yesno "Enable 24-hour auto-healing? (Checks every $HEAL_INTERVAL seconds)" 12 78; then
        (
            end_time=$(($(date +%s) + 86400))
            while [ "$(date +%s)" -lt "$end_time" ]; do
                CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
                if (( $(echo "$CPU_LOAD > $THRESHOLD_CPU" | bc -l) )); then
                    PID_TO_KILL=$(ps -eo pid,%cpu,comm --sort=-%cpu | awk 'NR==2{print $1}')
                    PROCESS_NAME=$(ps -eo pid,%cpu,comm --sort=-%cpu | awk 'NR==2{print $3}')
                    if [ -n "$PID_TO_KILL" ]; then
                        kill -9 "$PID_TO_KILL"
                        send_telegram_alert "🔧 Auto-heal: Killed $PROCESS_NAME (PID: $PID_TO_KILL)"
                    fi
                fi
                sleep "$HEAL_INTERVAL"
            done
            rm "/tmp/auto_heal.pid" 2>/dev/null
            send_telegram_alert "🕒 Auto-healing cycle completed"
        ) &
        echo $! > "/tmp/auto_heal.pid"
        whiptail --msgbox "✅ Auto-healing enabled for 24 hours" 10 70
        send_telegram_alert "✅ Auto-healing enabled"
    else
        whiptail --msgbox "Auto-healing remains inactive." 8 40
    fi
}

# Function to show logs
show_logs() {
    log_content=$(tail -n 50 "$LOG_FILE")
    whiptail --title "📜 System Logs" --scrolltext --textbox <(echo "$log_content") 20 90
}

# Main execution
while true; do
    display_stats
    if whiptail --title "Exit" --yesno "Exit system monitor?" 8 78; then
        whiptail --msgbox "Thank you for using the System Monitor!" 8 50
        break
    fi
done
