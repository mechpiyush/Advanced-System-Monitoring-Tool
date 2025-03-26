#!/bin/bash

# Set CPU Threshold
THRESHOLD=1

# Get CPU Usage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')

# Telegram Bot Credentials (Replace with New Secure Token)
BOT_TOKEN="7756648526:AAGgP5pXQuhhyg5gqz83WBbp2ScvUH0wrrI"
CHAT_ID="1276767407"
TELEGRAM_API="https://api.telegram.org/bot$BOT_TOKEN/sendMessage"

# Check CPU Usage
if (( $(echo "$CPU_USAGE > $THRESHOLD" | bc -l) )); then
    MESSAGE="⚠️ *High CPU Usage Alert!*%0A🔥 CPU Usage: $CPU_USAGE%%"
    
    # Send Message to Telegram
    curl -s -X POST "$TELEGRAM_API" -d chat_id="$CHAT_ID" -d text="$MESSAGE" -d parse_mode="Markdown"
fi

