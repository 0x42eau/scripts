#!/bin/bash

# Define variables
LOG_FILE="/var/log/command_no_output.log"
LOG_SCRIPT="/usr/local/bin/log_command.sh"
BASHRC_GLOBAL="/etc/bash.bashrc"
PROFILE_GLOBAL="/etc/profile"
ZSHRC_GLOBAL="/etc/zsh/zshrc"

# Create the log file and set permissions
sudo touch "$LOG_FILE" || { echo "Failed to create log file"; exit 1; }
sudo chmod 644 "$LOG_FILE" || { echo "Failed to set permissions on log file"; exit 1; }

# Create the logging script
cat << EOF > "$LOG_SCRIPT" || { echo "Failed to create logging script"; exit 1; }
#!/bin/bash

LOG_FILE="$LOG_FILE"

# Ensure the log file is writable
sudo touch "\$LOG_FILE" || { echo "Failed to touch log file"; exit 1; }
sudo chmod 644 "\$LOG_FILE" || { echo "Failed to set permissions on log file"; exit 1; }

# Logging function for Zsh and Bash
log_command_no_output() {
    local cmd_start_time=\$(date '+%Y-%m-%d %H:%M:%S')
    local cmd="\$1"
    local user=\$(whoami)
    local tty=\$(tty)
    
    # Log the start time, command, and user
    echo "[\$cmd_start_time] [\$user@\$tty] \$cmd" | sudo tee -a "\$LOG_FILE" > /dev/null
}

# Ensure that the log_command_no_output function runs before each prompt in Bash
if [ -n "\$BASH_VERSION" ]; then
    trap 'log_command_no_output "\$BASH_COMMAND"' DEBUG
fi

# Ensure that the log_command_no_output function runs before each prompt in Zsh
if [ -n "\$ZSH_VERSION" ]; then
    preexec() { log_command_no_output "\$1"; }
fi
EOF

# Make the logging script executable
sudo chmod +x "$LOG_SCRIPT" || { echo "Failed to make logging script executable"; exit 1; }

# Function to add source command to file
add_source_command() {
    local file="$1"
    if ! grep -q "source $LOG_SCRIPT" "$file"; then
        echo "source $LOG_SCRIPT" | sudo tee -a "$file" > /dev/null || { echo "Failed to modify $file"; return 1; }
    fi
}

# Add the logging script sourcing to global Bash configuration
add_source_command "$PROFILE_GLOBAL"
add_source_command "$BASHRC_GLOBAL"

# Add the logging script sourcing to global Zsh configuration
if [ -f "$ZSHRC_GLOBAL" ]; then
    add_source_command "$ZSHRC_GLOBAL"
else
    echo "$ZSHRC_GLOBAL not found, skipping Zsh configuration"
fi

echo "Command logging setup completed successfully."
