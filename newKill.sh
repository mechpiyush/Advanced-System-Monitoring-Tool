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

kill_process
