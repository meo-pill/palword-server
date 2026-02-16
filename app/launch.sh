#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Palword Server Management Script
# Supports starting, stopping, configuration, and monitoring of Palword servers

########################################################################################
# Configuration Constants and Path Definitions
########################################################################################

# Palword server installation paths and identifiers
Binaries="$APPLOCATION"
ScreenName="Palworld-server" # Base name for screen sessions running Palword servers

########################################################################################
# Cluster Management Functions
########################################################################################

# Start the Server
launch_server() {
    echo "Starting Server..."
    echo

    cmd="${Binaries}/PalServer.sh -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS -NumberOfWorkerThreadsServer=8"
    screen -dmS "$ScreenName" $cmd 
    echo "Cluster started."

    # Verify successful startup
    if is_server_running ; then
        echo "Palword server started."
        echo
        return 0
    else
        echo "Palword server failed to start."
        echo
        return 1
    fi
}

# Gracefully shutdown all running cluster servers
# Attempts to shutdown each map and cleans up port allocation files
shutdown_server() {
    if is_server_running ; then
        echo "Shutting down server..."
        
        # Send Ctrl+C signal to screen session to initiate graceful shutdown
        screen -S "$ScreenName" -X eval 'stuff "\003"'
        max_time=120  # Maximum time to wait for shutdown (2 minutes)
        
        # Wait for graceful shutdown with progress indicator
        elapsed=0
        printf "Waiting for server to shut down... (0/%d seconds)" $max_time
        while is_server_running && [ $elapsed -lt $max_time ]; do
            sleep 1
            elapsed=$((elapsed + 1))
            printf "\rWaiting for server to shut down... (%d/%d seconds)" $elapsed $max_time
        done
        echo "" # Move to next line after progress indicator
        
        # Handle shutdown timeout
        if is_server_running ; then
            echo "ERROR: Server failed to shut down within $max_time seconds."
            echo
            return 1
        fi
        
        echo "Server shut down."
        echo
        return 0
    else
        echo "Server is not running."
        echo
        return 1
    fi
}


########################################################################################
# Utility and Status Check Functions
########################################################################################

# Check if a map server is currently running
# Verifies existence of named screen session for the map
is_server_running() {
    # Check if the named screen session exists and is active
    if screen -list | grep -q "$ScreenName"; then
        return 0
    else
        return 1
    fi
}

########################################################################################
# System Monitoring Function
########################################################################################

# Real-time monitoring display for system resources and server status
# Shows CPU usage, memory usage, and active screen sessions
monitor() {
    # Cleanup function for graceful exit
    cleanup() {
        tput cnorm  # Show cursor again
        clear
        exit 0      # Exit the script entirely
    }
    
    # Handle Ctrl+C signal for clean exit
    trap cleanup SIGINT
    clear
    
    i=0
    tput sc     # Save cursor position
    tput civis  # Hide cursor for cleaner display
    
    # Continuous monitoring loop
    while true; do
        tput rc  # Restore cursor position for screen refresh
        
        # Display system resource usage
        top -b -n 1 | grep "Cpu(s)"                           # CPU usage summary
        awk '{print $1/1073741824 " GB"}' /sys/fs/cgroup/memory.current  # Memory usage in GB
        screen -list                                           # Active screen sessions
        
        sleep 1
        i=$((i + 1))
        
        # Clear screen every 30 seconds for fresh display
        if [[ $i -eq 30 ]] ; then
            i=0
            clear
        fi
    done
    
    # Show cursor again after loop ends (cleanup fallback)
    tput cnorm
}

########################################################################################
# Main Script Logic - Command Line Interface
########################################################################################

# Process command line arguments and execute appropriate functions
# Provides a comprehensive interface for ARK cluster management
case "$1" in
    start)
        launch_server
    ;;
    stop)
        shutdown_server
    ;;
    restart)
        shutdown_server
        launch_server
    ;;
    update)
        # DEPRECATED: Updates now handled during Docker build
        echo "Update is deprecated, rebuild the container to update the game server."
    ;;
    monitor)
        # Start real-time system monitoring display
        monitor
    ;;
    auto)
        # Automated startup mode (used by container entrypoint)
        echo "No update performed, this is now done in the Dockerfile"
        launch_server
    ;;
    *)
        # Display usage information for invalid commands
        echo "Usage: $0 {start|stop|config|add|remove|list|restart|monitor|auto}"
        echo ""
        echo "Commands:"
        echo "  start    - Start all configured maps in the cluster"
        echo "  stop     - Stop all running cluster servers"
        echo "  restart  - Restart the entire cluster"
        echo "  monitor  - Real-time system monitoring"
        echo "  auto     - Automated startup (used by container)"
        exit 1
    ;;
esac