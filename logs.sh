#!/bin/bash

# logs in /home/kali/command_history.log

# usage
# cp logger.sh /usr/local/bin/logger.sh
# chmod 755 /usr/local/bin/logger.sh
# source /usr/local/bin/logger.sh
# check if working:
# show_log_status

# try to enable if broken:
# enable_command_logging

# disable to be a dork
# disable_command_logging


# Configuration variables
LOG_FILE="/home/kali/command_history.log"  # Changed to Kali home directory
LOG_SCRIPT="/usr/local/bin/log_command.sh"
BASHRC_GLOBAL="/etc/bash.bashrc"
PROFILE_GLOBAL="/etc/profile"
ZSHRC_GLOBAL="/etc/zsh/zshrc"
MAX_LOG_SIZE_MB=100
ROTATE_BACKUP_COUNT=5
DISABLE_FLAG="/tmp/.disable_cmd_log"
MIN_FREE_SPACE_MB=500

# Function to check available disk space
check_disk_space() {
    local mount_point=$(dirname "$LOG_FILE")
    local available_space=$(df -m "$mount_point" | awk 'NR==2 {print $4}')
    
    if [ "$available_space" -lt "$MIN_FREE_SPACE_MB" ]; then
        logger -t "command_logger" "Warning: Low disk space. Logging suspended."
        return 1
    fi
    return 0
}

# Function to rotate logs when they get too large
rotate_logs() {
    if [ -f "$LOG_FILE" ] && [ "$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE")" -gt $((MAX_LOG_SIZE_MB * 1024 * 1024)) ]; then
        for i in $(seq $((ROTATE_BACKUP_COUNT-1)) -1 1); do
            [ -f "${LOG_FILE}.$i" ] && mv "${LOG_FILE}.$i" "${LOG_FILE}.$((i+1))"
        done
        mv "$LOG_FILE" "${LOG_FILE}.1"
        touch "$LOG_FILE"
        chmod 600 "$LOG_FILE"  # Changed to more secure permissions
    fi
}

# Function to safely write to log file
safe_log_write() {
    local log_entry="$1"
    
    # Check if logging is disabled
    if [ -f "$DISABLE_FLAG" ]; then
        return 0
    fi
    
    # Create log file if it doesn't exist
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
        chmod 600 "$LOG_FILE"  # Changed to more secure permissions
    fi
    
    # Check disk space
    if ! check_disk_space; then
        return 1
    fi
    
    # Attempt to write to log file
    if ! echo "$log_entry" >> "$LOG_FILE" 2>/dev/null; then
        logger -t "command_logger" "Error: Failed to write to log file"
        return 1
    fi
    
    # Check log size and rotate if necessary
    if [ -f "$LOG_FILE" ]; then
        local size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE")
        if [ "$size" -gt $((MAX_LOG_SIZE_MB * 1024 * 1024)) ]; then
            rotate_logs
        fi
    fi
    
    return 0
}

# Enhanced logging function for Zsh
log_command_no_output_zsh() {
    local cmd_start_time=$(date '+%Y-%m-%d %H:%M:%S')
    local cmd="$1"
    local user=$(whoami)
    local tty=$(tty 2>/dev/null || echo "unknown-tty")
    local hostname=$(hostname)
    local pid=$$
    
    # Create detailed log entry
    local log_entry="[$cmd_start_time] [$user@$hostname:$tty] (PID:$pid) $cmd"
    safe_log_write "$log_entry"
}

# Enhanced logging function for Bash
log_command_no_output_bash() {
    # Skip logging for common internal commands
    case "$BASH_COMMAND" in
        *"PROMPT_COMMAND="*|*"PS1="*|*"trap "*|*"LOGIN_SHELL="*)
            return
            ;;
    esac
    
    local cmd_start_time=$(date '+%Y-%m-%d %H:%M:%S')
    local cmd="$BASH_COMMAND"
    local user=$(whoami)
    local tty=$(tty 2>/dev/null || echo "unknown-tty")
    local hostname=$(hostname)
    local pid=$$
    
    # Create detailed log entry
    local log_entry="[$cmd_start_time] [$user@$hostname:$tty] (PID:$pid) $cmd"
    safe_log_write "$log_entry"
}

# Helper functions for users to control logging
disable_command_logging() {
    touch "$DISABLE_FLAG"
    echo "Command logging disabled"
}

enable_command_logging() {
    rm -f "$DISABLE_FLAG"
    echo "Command logging enabled"
}

show_log_status() {
    if [ -f "$DISABLE_FLAG" ]; then
        echo "Command logging is currently DISABLED"
    else
        echo "Command logging is currently ENABLED"
    fi
    
    if [ -f "$LOG_FILE" ]; then
        echo "Current log file size: $(du -h "$LOG_FILE" | cut -f1)"
        echo "Log file location: $LOG_FILE"
    else
        echo "Log file does not exist yet - it will be created when logging begins"
    fi
}

# Main execution logic
setup_logging() {
    # Only proceed if we're in an interactive shell and not during login
    if [[ $- == *i* ]] && [[ -z "$LOGIN_SHELL" ]]; then
        export LOGIN_SHELL=1  # Prevent recursive sourcing
        
        # Set up command logging for the appropriate shell
        if [ -n "$BASH_VERSION" ]; then
            trap 'log_command_no_output_bash' DEBUG
        elif [ -n "$ZSH_VERSION" ]; then
            preexec() { log_command_no_output_zsh "$1"; }
        fi
    fi
}

# Determine if the script is being sourced or executed directly
(return 0 2>/dev/null) && sourced=1 || sourced=0

if [ $sourced -eq 1 ]; then
    # Script is being sourced - set up logging
    setup_logging
else
    # Script is being executed directly - perform installation
    # Create the log file if it doesn't exist
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"  # Changed to more secure permissions
    
    # Safely add the logging script to global configurations
    for config_file in "$PROFILE_GLOBAL" "$BASHRC_GLOBAL" "$ZSHRC_GLOBAL"; do
        if [ -f "$config_file" ]; then
            # Remove any existing entries
            sed -i '/source.*log_command\.sh/d' "$config_file"
            # Add new entry with safeguard
            echo "[ -f \"$LOG_SCRIPT\" ] && source \"$LOG_SCRIPT\"" >> "$config_file"
        fi
    done
    
    echo "Enhanced command logging setup completed successfully."
    echo "Log file will be created at: $LOG_FILE"
fi
