# Function to monitor network bandwidth
monitor_network() {
    # Check if ifstat is installed
    if ! command -v ifstat &> /dev/null; then
        if whiptail --yesno "ifstat is not installed. Install it now?" 8 50; then
            sudo yum install ifstat -y || {
                whiptail --msgbox "Failed to install ifstat. Network monitoring unavailable." 8 50
                return 1
            }
        else
            return 1
        fi
    fi

    # Get active network interface
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    [ -z "$INTERFACE" ] && INTERFACE="ens5"

    # Start monitoring
    whiptail --title "🌐 Network Bandwidth Monitoring" --msgbox "Starting live monitoring for interface $INTERFACE..." 8 60
    
    # Show live stats for 10 seconds (adjustable)
    {
        echo "Live Network Bandwidth (KB/s)"
        echo "Interface: $INTERFACE"
        echo "Press Ctrl+C to stop"
        echo "--------------------------"
        echo "   RX (Download)   TX (Upload)"
        ifstat -T -n -i "$INTERFACE" 1 10 | awk 'NR>2 {print $1"   "$2}'
    } > /tmp/network_stats.txt
    
    whiptail --title "🌐 Network Bandwidth Results" --textbox /tmp/network_stats.txt 20 60
    rm /tmp/network_stats.txt
}

monitor_network
