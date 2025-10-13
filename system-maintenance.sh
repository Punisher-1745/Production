#!/bin/bash

# System Maintenance Script for Debian
# Performs: update, upgrade, autoclean, autoremove
# Checks for and handles reboots if needed
# Sends notifications to Gotify

# Configuration
GOTIFY_URL=http://"192.168.1.109"
GOTIFY_TOKEN="AkTBqKmUn9D3rfq"
SCRIPT_NAME="System Maintenance"
HOSTNAME=$(hostname)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to send Gotify notification
send_gotify_notification() {
    local title="$1"
    local message="$2"
    local priority="${3:-5}" # Default priority 5
    
    if command -v curl &> /dev/null; then
        curl -X POST "$GOTIFY_URL/message" \
            -H "Content-Type: application/json" \
            -d "{
                \"title\": \"$title\",
                \"message\": \"$message\",
                \"priority\": $priority
            }" \
            --connect-timeout 10 \
            --max-time 30 \
            --silent \
            --output /dev/null \
            --show-error
    else
        echo "Warning: curl not available, cannot send notification"
    fi
}

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
    logger -t "system-maintenance" "$1"
}

# Initialize variables
REBOOT_REQUIRED=false
UPGRADE_SUCCESS=true
NOTIFICATION_MESSAGE=""

log_message "Starting system maintenance"

# Send start notification
send_gotify_notification "🔄 $SCRIPT_NAME - $HOSTNAME" "System maintenance started on $HOSTNAME" 5

# Update package lists
log_message "Updating package lists..."
if apt-get update; then
    log_message "Package lists updated successfully"
    NOTIFICATION_MESSAGE+="✅ Package lists updated successfully\n"
else
    log_message "ERROR: Failed to update package lists"
    NOTIFICATION_MESSAGE+="❌ Failed to update package lists\n"
    UPGRADE_SUCCESS=false
fi

# Upgrade packages (non-interactive)
log_message "Upgrading packages..."
if apt-get upgrade -y; then
    log_message "Packages upgraded successfully"
    NOTIFICATION_MESSAGE+="✅ Packages upgraded successfully\n"
else
    log_message "ERROR: Failed to upgrade packages"
    NOTIFICATION_MESSAGE+="❌ Failed to upgrade packages\n"
    UPGRADE_SUCCESS=false
fi

# Perform dist-upgrade for kernel updates
log_message "Performing dist-upgrade..."
if apt-get dist-upgrade -y; then
    log_message "Dist-upgrade completed successfully"
    NOTIFICATION_MESSAGE+="✅ Dist-upgrade completed successfully\n"
else
    log_message "ERROR: Failed to complete dist-upgrade"
    NOTIFICATION_MESSAGE+="❌ Failed to complete dist-upgrade\n"
    UPGRADE_SUCCESS=false
fi

# Clean up
log_message "Cleaning up packages..."
if apt-get autoclean -y && apt-get autoremove -y --purge; then
    log_message "Cleanup completed successfully"
    NOTIFICATION_MESSAGE+="✅ Package cleanup completed\n"
else
    log_message "ERROR: Cleanup failed"
    NOTIFICATION_MESSAGE+="⚠️ Package cleanup had issues\n"
fi

# Check if reboot is required
if [ -f /var/run/reboot-required ]; then
    REBOOT_REQUIRED=true
    REBOOT_PKGS=$(cat /var/run/reboot-required.pkgs 2>/dev/null || echo "unknown packages")
    log_message "Reboot required for: $REBOOT_PKGS"
    NOTIFICATION_MESSAGE+="\n🔁 Reboot required for: $REBOOT_PKGS\n"
fi

# Send completion notification
if [ "$UPGRADE_SUCCESS" = true ]; then
    if [ "$REBOOT_REQUIRED" = true ]; then
        send_gotify_notification "⚠️ $SCRIPT_NAME - $HOSTNAME" "Maintenance completed but reboot required!\n\n$NOTIFICATION_MESSAGE" 8
        log_message "Maintenance completed - REBOOT REQUIRED"
        
        # Perform reboot
        log_message "Initiating system reboot..."
        send_gotify_notification "🔄 $SCRIPT_NAME - $HOSTNAME" "System reboot initiated for $HOSTNAME" 9
        
        # Wait a moment for notification to be sent
        sleep 5
        
        # Reboot the system
        shutdown -r now "System maintenance reboot"
    else
        send_gotify_notification "✅ $SCRIPT_NAME - $HOSTNAME" "Maintenance completed successfully!\n\n$NOTIFICATION_MESSAGE" 5
        log_message "Maintenance completed successfully - No reboot required"
    fi
else
    send_gotify_notification "❌ $SCRIPT_NAME - $HOSTNAME" "Maintenance completed with errors!\n\n$NOTIFICATION_MESSAGE" 9
    log_message "Maintenance completed with errors"
fi
