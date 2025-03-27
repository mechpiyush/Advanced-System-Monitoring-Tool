#!/bin/bash

# Network Speed Dashboard
# Uses /proc/net/dev for maximum compatibility
# Press Ctrl+C to exit

# Detect active network interface
INTERFACE=$(ip route | awk '/default/ {print $5}' | head -n1)
[ -z "$INTERFACE" ] && INTERFACE="eth0"

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

# Get initial values
prev_rx=$(awk "/$INTERFACE/ {print \$2}" /proc/net/dev)
prev_tx=$(awk "/$INTERFACE/ {print \$10}" /proc/net/dev)

# Main monitoring function
monitor_network() {
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

Total Downloaded: $(human_format $curr_rx)
Total Uploaded:   $(human_format $curr_tx)

Press Ctrl+C to exit"
        
        # Display in whiptail with auto-refresh
        whiptail --title "Network Speed Monitor" --infobox "$message" 20 60
        sleep 1
    done
}

# Choose interface if not specified
if [ -z "$1" ]; then
    INTERFACE=$(whiptail --title "Select Network Interface" --menu "Choose the interface to monitor:" 15 50 5 \
    $(ls /sys/class/net | awk '{print $1 " \"Network Interface\""}') 3>&1 1>&2 2>&3)
    
    [ -z "$INTERFACE" ] && exit 1
fi

# Start monitoring in GUI mode
monitor_network
