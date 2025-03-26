#!/bin/bash

# Define CPU Threshold
THRESHOLD=1

# Get CPU Usage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')

# Check if CPU exceeds threshold
if (( $(echo "$CPU_USAGE > $THRESHOLD" | bc -l) )); then
    SUBJECT="⚠️ High CPU Usage Alert!"
    MESSAGE="ALERT! CPU Usage is at $CPU_USAGE%. Immediate action required."
    TO_EMAIL="seshuvangapandu@gmail.com"

    echo "$MESSAGE" | mail -s "$SUBJECT" "$TO_EMAIL"
fi

