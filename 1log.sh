LOG_FILE="/log/sys_monitor.log"

# Function to show logs with working OK button and latest data
show_logs() {
    # Show the latest 50 lines of the log file
    log_content=$(tail -n 50 "$LOG_FILE")

    # Display the logs with the option to scroll
    whiptail --title "📜 System Monitor Logs" --scrolltext --textbox <(echo "$log_content") 20 90
}

show_logs
