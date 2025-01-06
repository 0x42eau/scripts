#!/bin/bash

# Define variables
LOG_FILE="/var/log/command_no_output.log"
LOG_SCRIPT="/usr/local/bin/log_command.sh"
BASHRC_GLOBAL="/etc/bash.bashrc"
PROFILE_GLOBAL="/etc/profile"
ZSHRC_GLOBAL="/etc/zsh/zshrc"

# Create the log file and set permissions
touch "$LOG_FILE"
chmod 666 "$LOG_FILE"

# Create the logging script
cat << 'EOF' > "$LOG_SCRIPT"
#!/bin/bash

LOG_FILE="/var/log/command_no_output.log"  # Define the log file location

# Ensure the log file is writable
touch "$LOG_FILE"
chmod 666 "$LOG_FILE"

# Logging function for Zsh
log_command_no_output_zsh() {
    local cmd_start_time=$(date '+%Y-%m-%d %H:%M:%S')
    local cmd="$1"
    local user=$(whoami)
    local tty=$(tty)

    # Log the start time, command, and user
    echo "[$cmd_start_time] [$user@$tty] $cmd" >> "$LOG_FILE"
}

# Logging function for Bash
log_command_no_output_bash() {
    local cmd_start_time=$(date '+%Y-%m-%d %H:%M:%S')
    local cmd="$BASH_COMMAND"
    local user=$(whoami)
    local tty=$(tty)

    # Log the start time, command, and user
    echo "[$cmd_start_time] [$user@$tty] $cmd" >> "$LOG_FILE"
}

# Ensure that the log_command_no_output function runs before each prompt in Bash
if [ -n "$BASH_VERSION" ]; then
    trap 'log_command_no_output_bash' DEBUG
fi

# Ensure that the log_command_no_output function runs before each prompt in Zsh
if [ -n "$ZSH_VERSION" ]; then
    preexec() { log_command_no_output_zsh "$1"; }
fi
EOF

# Make the logging script executable
chmod +x "$LOG_SCRIPT"

# Add the logging script sourcing to global Bash configuration
if ! grep -q "source $LOG_SCRIPT" "$PROFILE_GLOBAL"; then
    echo "source $LOG_SCRIPT" >> "$PROFILE_GLOBAL"
fi

if ! grep -q "source $LOG_SCRIPT" "$BASHRC_GLOBAL"; then
    echo "source $LOG_SCRIPT" >> "$BASHRC_GLOBAL"
fi

# Add the logging script sourcing to global Zsh configuration
if [ -f "$ZSHRC_GLOBAL" ]; then
    if ! grep -q "source $LOG_SCRIPT" "$ZSHRC_GLOBAL"; then
        echo "source $LOG_SCRIPT" >> "$ZSHRC_GLOBAL"
    fi
else
    echo "$ZSHRC_GLOBAL not found, skipping Zsh configuration"
fi



echo "Command logging setup completed successfully."


