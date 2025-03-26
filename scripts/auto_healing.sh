#!/bin/bash
THRESHOLD=80
CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')

if (( $(echo "$CPU_LOAD > $THRESHOLD" | bc -l) )); then
    echo "⚠️ High CPU detected! Killing processes..."
    kill -9 $(ps -eo pid,%cpu --sort=-%cpu | awk 'NR==2 {print $1}')
fi

