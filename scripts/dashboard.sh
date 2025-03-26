#!/bin/bash

while true; do
    CHOICE=$(whiptail --title "System Monitor" --menu "Choose an option" 15 60 5 \
        "1" "View CPU Usage" \
        "2" "View Memory Usage" \
        "3" "View Disk Usage" \
        "4" "View Network Activity" \
        "5" "Exit" 3>&1 1>&2 2>&3)

    case $CHOICE in
        1) top -bn1 | grep "Cpu(s)";;
        2) free -m;;
        3) df -h;;
        4) netstat -tunlp;;
        5) exit;;
    esac
done

