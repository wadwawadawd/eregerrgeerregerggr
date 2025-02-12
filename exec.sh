#!/bin/bash

CDN_URL="https://raw.githubusercontent.com/wadwawadawd/eregerrgeerregerggr/refs/heads/main/Agent.pm"
TARGET_FILE="/usr/share/perl5/PVE/API2/Qemu/Agent.pm"

check_connection() {
    ping -c 1 google.com &> /dev/null
    return $?
}

change_dns() {
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "DNS changed to Google DNS (8.8.8.8)."
}

attempt_download() {
    curl -o "$TARGET_FILE" "$CDN_URL"
    return $?
}

handle_error() {
    local error_code=$1
    local error_message=$2

    case $error_code in
        6)
            echo "Curl error: Could not resolve host. Attempting to change DNS..."
            change_dns
            sleep 5
            if ! check_connection; then
                echo "Still no internet connection after DNS change. Exiting."
                exit 1
            fi
            ;;
        7)
            echo "Curl error: Failed to connect to the server. Retrying..."
            sleep 5
            attempt_download
            if [ $? -ne 0 ]; then
                echo "Download failed again. Exiting."
                exit 1
            fi
            ;;
        28)
            echo "Curl error: Operation timed out. Retrying..."
            sleep 5
            attempt_download
            if [ $? -ne 0 ]; then
                echo "Download failed again. Exiting."
                exit 1
            fi
            ;;
        35)
            echo "Curl error: SSL connect error. Trying without SSL verification..."
            curl -k -o "$TARGET_FILE" "$CDN_URL"
            if [ $? -ne 0 ]; then
                echo "Download failed without SSL verification. Exiting."
                exit 1
            fi
            ;;
        60)
            echo "Curl error: SSL certificate problem. Trying to bypass SSL certificate validation..."
            curl -k -o "$TARGET_FILE" "$CDN_URL"
            if [ $? -ne 0 ]; then
                echo "Download failed after bypassing SSL certificate. Exiting."
                exit 1
            fi
            ;;
        *)
            echo "Error: $error_message"
            exit 1
            ;;
    esac
}

check_and_restart_services() {
    systemctl restart pveproxy
    if [ $? -ne 0 ]; then
        echo "Failed to restart pveproxy. Exiting."
        exit 1
    fi

    systemctl restart pvedaemon
    if [ $? -ne 0 ]; then
        echo "Failed to restart pvedaemon. Exiting."
        exit 1
    fi
}

handle_file_exists() {
    if [ -f "$TARGET_FILE" ]; then
        echo "File already exists: $TARGET_FILE. Removing it."
        rm -f "$TARGET_FILE"
        if [ $? -ne 0 ]; then
            echo "Failed to remove the existing file. Exiting."
            exit 1
        fi
    fi
}

attempt_download_with_retries() {
    attempt_download
    DOWNLOAD_STATUS=$?

    if [ $DOWNLOAD_STATUS -ne 0 ]; then
        handle_error $DOWNLOAD_STATUS "Failed to download the file from the CDN."
    fi
}

check_internet() {
    if ! check_connection; then
        echo "No internet connection. Trying to change DNS to Google DNS."
        change_dns
        sleep 5
        if ! check_connection; then
            echo "Still no internet connection. Exiting."
            exit 1
        fi
    fi
}

check_internet

handle_file_exists

attempt_download_with_retries

check_and_restart_services

echo "PVE done."
