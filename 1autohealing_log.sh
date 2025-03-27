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

# Function to send Telegram alert
send_telegram_alert() {
    local message="⚠ System Alert%0A$(date)%0A%0A$1"
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

# Function to toggle auto-healing for CPU
auto_heal() {
    # Check if auto-heal is already running
    if [ -f "/tmp/auto_heal.pid" ]; then
        PID=$(cat /tmp/auto_heal.pid)
        if kill -0 "$PID" 2>/dev/null; then
            # Auto-heal is running, prompt to disable
            if whiptail --yesno "Auto-healing is currently active. Do you want to disable it?" 8 78; then
                kill "$PID"
                rm "/tmp/auto_heal.pid"
                whiptail --msgbox "Auto-healing has been disabled." 8 40
                send_telegram_alert "🛑 Auto-healing has been manually disabled."
            fi
            return
        else
            # Stale PID file
            rm "/tmp/auto_heal.pid"
        fi
    fi

    # Auto-heal not running, prompt to enable
    if whiptail --yesno "Enable auto-healing? When enabled, it will run for 24 hours, checking every $HEAL_INTERVAL seconds and killing the top CPU process if usage exceeds ${THRESHOLD_CPU}%." 12 78; then
        (
            end_time=$(($(date +%s) + 86400)) # 24 hours
            while [ "$(date +%s)" -lt "$end_time" ]; do
                CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
		if [[ $(echo "$CPU_LOAD > $THRESHOLD_CPU" | bc -l) -eq 1 ]]; then
                    PID_TO_KILL=$(ps -eo pid,%cpu,comm --sort=-%cpu | awk 'NR==2{print $1}')
                    PROCESS_NAME=$(ps -eo pid,%cpu,comm --sort=-%cpu | awk 'NR==2{print $3}')
                    if [ -n "$PID_TO_KILL" ]; then
                        kill -9 "$PID_TO_KILL"
                        send_telegram_alert "🔧 Auto-heal: High CPU ($CPU_LOAD% > $THRESHOLD_CPU%). Killed process $PROCESS_NAME (PID: $PID_TO_KILL)."
                    fi
                fi
                sleep "$HEAL_INTERVAL"
            done
            rm "/tmp/auto_heal.pid" 2>/dev/null
            send_telegram_alert "🕒 Auto-healing cycle completed after 24 hours and is now inactive."
        ) &
        echo $! > "/tmp/auto_heal.pid"
        whiptail --msgbox "✅ Auto-healing has been enabled for 24 hours. A Telegram alert will notify you when it completes." 10 70
        send_telegram_alert "✅ Auto-healing has been enabled. It will run for 24 hours, checking every $HEAL_INTERVAL seconds."
    else
        whiptail --msgbox "Auto-healing remains inactive." 8 40
    fi
}
# Function to show logs with working OK button and latest data

show_logs() {
    # Show the latest 50 lines of the log file
    log_content=$(tail -n 50 "$LOG_FILE")

    # Display the logs with the option to scroll
    whiptail --title "📜 System Monitor Logs" --scrolltext --textbox <(echo "$log_content") 20 90
}
# Main execution
while true; do
    display_stats
    if whiptail --title "Exit" --yesno "Are you sure you want to exit the system monitor?" 8 78; then
        whiptail --msgbox "Thank you for using the System Monitor!" 8 50
        break
    fi
done
