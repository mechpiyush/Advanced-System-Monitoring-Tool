#!/bin/bash

# Configuration
LOG_FILE="/home/ec2-user/major_project/Advanced-System-Monitoring-Tool/scripts/sys_monitor.log"
THRESHOLD_CPU=3
BOT_TOKEN="7756648526:AAGgP5pXQuhhyg5gqz83WBbp2ScvUH0wrrI"
CHAT_ID="1276767407"
TELEGRAM_API="https://api.telegram.org/bot$BOT_TOKEN/sendMessage"
REFRESH_RATE=1  # seconds for dashboard refresh
HEAL_INTERVAL=60  # seconds between auto-heal checks

# Initialize log file if not exists
[ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"

# Function to convert bytes to human readable format
human_format() {
    local bytes=$1
    if (( bytes > 10**9 )); then
        echo "$(bc <<< "scale=2; $bytes / 1024 / 1024 / 1024") GB"
    elif (( bytes > 10**6 )); then
        echo "$(bc <<< "scale=2; $bytes / 1024 / 1024") MB"
    elif (( bytes > 10**3 )); then
        echo "$(bc <<< "scale=2; $bytes / 1024") KB"
    else
        echo "$bytes B"
    fi
}

# Function to log system data
log_system_data() {
    echo "$(date) | " >> "$LOG_FILE"
    echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4"%"}')" >> "$LOG_FILE"
    echo "Memory Usage/ $(free -m | awk 'NR==2{printf "Memory: %s/%sMB (%.2f%%)\n", $3, $2, $3*100/$2 }')" >> "$LOG_FILE"
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
        DISK_IO=$(iostat -d | awk 'NR==4 {print $2}' 2>/dev/null || echo "N/A")

        # Get top processes
        TOP_MEM=$(ps -eo pid,user,%mem,comm --sort=-%mem | head -6 | awk '{printf "%-8s %-10s %-5s %s\n", $1, $2, $3, $4}' | tr '\n' '|')

        # Create whiptail menu
        choice=$(whiptail --title "🖥  SYSTEM MONITOR DASHBOARD" --menu "\
CPU Usage: $CPU% | Memory: $MEM_USED/$MEM_TOTAL MB ($MEM_PERCENT%) | Disk: $DISK
Network: $NET conn | Disk I/O: $DISK_IO MB/s

Top Memory Processes:
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

kill_process() {
    # Get a list of processes sorted by CPU usage
    PROCESS_LIST=$(ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | awk '{printf "%s \"%s (CPU: %s%%, MEM: %s%%)\"\n", $1, $5, $3, $4}' | head -n 15)

    # Ask user for a search term
    SEARCH_TERM=$(whiptail --inputbox "Enter process name to search (leave empty for all):" 8 60 3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return  # User canceled input

    if [ -n "$SEARCH_TERM" ]; then
        FILTERED_LIST=$(ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | grep -i "$SEARCH_TERM" | awk '{printf "%s \"%s (CPU: %s%%, MEM: %s%%)\"\n", $1, $5, $3, $4}' | head -n 10)

        # Check if search found no results
        if [ -z "$FILTERED_LIST" ]; then
            whiptail --msgbox "Invalid search... Process not found" 8 40
            return 1
        fi
    else
        FILTERED_LIST="$PROCESS_LIST"
    fi

    # Show process list in whiptail menu
    PID=$(whiptail --title "Select Process to Kill" --menu "Select a process to kill:" 20 80 10 $FILTERED_LIST 3>&1 1>&2 2>&3)
    [ -z "$PID" ] && return  # User canceled selection

    # Kill the selected process
    if kill -9 "$PID" 2>/dev/null; then
        send_telegram_alert "Process $PID was killed."
        whiptail --msgbox "✅ Process $PID killed!" 8 40
    else
        whiptail --msgbox "❌ Failed to kill process $PID!" 8 40
    fi
}

# Function to monitor network bandwidth
monitor_network() {
    # Detect active network interface
    INTERFACE=$(ip route | awk '/default/ {print $5}' | head -n1)
    [ -z "$INTERFACE" ] && INTERFACE="eth0"

    # Get initial values
    prev_rx=$(awk "/$INTERFACE/ {print \$2}" /proc/net/dev)
    prev_tx=$(awk "/$INTERFACE/ {print \$10}" /proc/net/dev)

    while true; do
        # Get current values
        curr_rx=$(awk "/$INTERFACE/ {print \$2}" /proc/net/dev)
        curr_tx=$(awk "/$INTERFACE/ {print \$10}" /proc/net/dev)
        
        # Calculate differences
        rx_diff=$((curr_rx - prev_rx))
        tx_diff=$((curr_tx - prev_tx))
        
        # Convert to bits and calculate speed (1 byte = 8 bits)
        rx_speed=$((rx_diff * 8))
        tx_speed=$((tx_diff * 8))
        
        # Update previous values
        prev_rx=$curr_rx
        prev_tx=$curr_tx
        
        # Format speeds
        rx_human=$(human_format $rx_speed)
        tx_human=$(human_format $tx_speed)
        
        # Create display message
        message="\
Network Interface: $INTERFACE

Download Speed: $rx_human/s
Upload Speed:   $tx_human/s

Press ESC to return to main menu"
        
        # Display in whiptail with option to refresh or exit
        choice=$(whiptail --title "🌐 Network Bandwidth Monitor" --menu "$message" 25 90 2 \
        "1" "Refresh" \
        "2" "Exit" 3>&1 1>&2 2>&3)
        
        [ "$choice" != "1" ] && break

	# Sending telegram alert
	send_telegram_alert "$message"
    done
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
    log_content=$(tail -50 "$LOG_FILE")
    echo "$log_content" > /tmp/log_temp.txt
    whiptail --title "📜 System Monitor Logs" --scrolltext --textbox /tmp/log_temp.txt 25 90
    rm /tmp/log_temp.txt

    log_content_tele=$(tail -n 10 "$LOG_FILE")
    send_telegram_alert "$log_content_tele"
}

# Main execution
while true; do
    display_stats
    if whiptail --title "Exit" --yesno "Are you sure you want to exit the system monitor?" 8 78; then
        whiptail --msgbox "Thank you for using the System Monitor!" 8 50
        break
    fi
done
