#!/bin/bash

# Function to get system stats and render UI
get_stats() {
    clear
    echo -e "\033[1;32m╔═════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;32m║              🖥️  ADVANCED SYSTEM MONITOR            ║\033[0m"
    echo -e "\033[1;32m╠═════════════════════════════════════════════════════╣\033[0m"

    # 🟢 CPU Usage
    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    echo -e "\033[1;34m║ 🔥 CPU Usage: $CPU%                                 ║\033[0m"

    # 🟢 Memory Usage
    MEM_TOTAL=$(free -m | awk 'NR==2{print $2}')
    MEM_USED=$(free -m | awk 'NR==2{print $3}')
    MEM_PERCENT=$(( 100 * MEM_USED / MEM_TOTAL ))
    echo -e "\033[1;34m║ 📌 Memory Usage: $MEM_USED MB / $MEM_TOTAL MB ($MEM_PERCENT%) 		║\033[0m"

    # 🟢 Disk Usage
    DISK=$(df -h / | awk 'NR==2 {print $5}')
    echo -e "\033[1;34m║ 💾 Disk Usage: $DISK                                 ║\033[0m"

    # 🟢 Network Usage
    NET=$(ss -s | grep "estab" | awk '{print $4}')
    echo -e "\033[1;34m║ 🌐 Active Connections: $NET                         ║\033[0m"

    # 🟢 Disk I/O Usage
    DISK_IO=$(iostat -d | awk 'NR==4 {print $2}')
    echo -e "\033[1;34m║ 📊 Disk I/O: $DISK_IO MB/s                          ║\033[0m"

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
    echo -e "\n\033[1;31m⚠️  Killing High Resource Usage Process\033[0m"
    read -p "Enter PID to kill: " PID
    kill -9 $PID
    echo -e "✅ Process $PID killed!"
}

# Function to monitor network bandwidth
monitor_network() {
    echo -e "\n\033[1;36m🌐 Live Network Bandwidth Usage\033[0m"
    watch -n 1 ifstat
}

# Function to send alerts
send_alert() {
    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    if (( $(echo "$CPU > 85" | bc -l) )); then
        echo "⚠️ High CPU Usage Detected! ($CPU%)"
        # Send alert (extend this for email/Slack integration)
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
    echo -e "4️⃣  Exit"
    read -p "👉 Select an option: " OPTION

    case $OPTION in
        1) continue ;;
        2) kill_process ;;
        3) monitor_network ;;
        4) exit ;;
        *) echo "Invalid choice!";;
    esac
done

