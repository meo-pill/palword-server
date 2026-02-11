#!/bin/bash

# ARK Server Container Entrypoint Script
# Handles container initialization, SSH setup, backup management, and ARK server startup
# Provides graceful shutdown handling and automated backup services

# Validate critical environment variables at startup
# Ensure backup configuration is valid to prevent runtime errors
if [ -z "$MAX_BACKUPS" ] || [ "$MAX_BACKUPS" -lt 1 ]; then
    echo "ERROR: MAX_BACKUPS must be >= 1"
    exit 1
fi

# Validate save directory exists (should be mounted volume)
if [ ! -d "$SAVE_DIR" ]; then
    echo "ERROR: SAVE_DIR '$SAVE_DIR' does not exist"
    exit 1
fi

# Container shutdown handler function
# Provides graceful shutdown sequence for ARK servers and SSH service
# Called when container receives SIGTERM or SIGINT signals
shutdown() {
    echo "Container shutdown initiated..."
    
    # Notify connected SSH users about impending shutdown
    wall "WARNING: Server will shutdown in 30 seconds. Please disconnect."
    
    # Gracefully stop ARK servers (allows proper save of game data)
    echo "Stopping ARK servers..."
    launch.sh stop
    
    # Stop SSH service last to allow monitoring until the end
    echo "Stopping SSH service..."
    sudo /etc/init.d/ssh stop
    
    echo "Shutdown completed."
    exit 0
}

# Initial container setup and SSH configuration
# Manages SSH host keys and authorized_keys for secure remote access
# Ensures persistent SSH configuration across container restarts
setup () {
    # Create SSH configuration directory in persistent volume if it doesn't exist
    if [ ! -d "$CONFIG_DIR/ssh" ]; then
        echo "Creating SSH configuration directory..."
        mkdir -p "$CONFIG_DIR/ssh"
    fi
    
    # Generate SSH host keys if not present in persistent storage
    # This ensures SSH host identity is maintained across container restarts
    if [ -z "$(ls -A "$CONFIG_DIR/ssh")" ]; then
        echo "Generating SSH host keys..."
        ssh-keygen -A
        cp /etc/ssh/ssh_host_*_key.pub "$CONFIG_DIR/ssh/"
        cp /etc/ssh/ssh_host_*_key "$CONFIG_DIR/ssh/"
        echo "SSH host keys generated and copied to persistent volume"
    else
        echo "SSH host keys already present in persistent volume"
        # Copy existing SSH keys from persistent storage to container
        cp "$CONFIG_DIR"/ssh/ssh_host_*_key /etc/ssh/
        cp "$CONFIG_DIR"/ssh/ssh_host_*_key.pub /etc/ssh/
        echo "SSH host keys loaded from persistent volume"
    fi

    # Configure SSH authorized keys for palword user access
    echo "Configuring SSH service..."
    mkdir -p $HOME/.ssh
    chmod 700 $HOME/.ssh
    touch "$CONFIG_DIR/authorized_keys"
    cp "$CONFIG_DIR/authorized_keys" $HOME/.ssh/authorized_keys
    chmod 600 $HOME/.ssh/authorized_keys    # Secure permissions for private key file
    chown palword:game-server $HOME/.ssh/authorized_keys
    echo "SSH service configured"
}

# Register signal handlers for graceful container shutdown
trap shutdown SIGTERM SIGINT

# Execute initial setup procedures
setup

# Start SSH service for remote administration access
sudo /etc/init.d/ssh start
echo "SSH service started"

# Start cron service for scheduled tasks
sudo service cron start
echo "Cron service started"

# Configure directory permissions for game-server group access
echo "Setting up backup and configuration directory permissions..."
chmod -R g+rw "$SAVE_DIR" "$CONFIG_DIR"

# Launch ARK server cluster in automated mode
echo "Starting ARK servers..."
launch.sh auto

# Keep container running and wait for signals
# Uses tail to maintain container lifecycle while allowing signal handling
echo "Servers started, container operational"
tail -f /dev/null &
wait $!