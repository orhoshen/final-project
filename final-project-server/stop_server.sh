#!/bin/bash
# Piano Game Server - Stop Script
# This script provides robust server shutdown with proper cleanup

set -e  # Exit on any error

# Configuration
SERVER_PORT=5001
PIDFILE="server.pid"
LOGFILE="server.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to stop server by PID
stop_server_by_pid() {
    local pid=$1
    print_status "Stopping server with PID $pid..."
    
    # Try graceful shutdown first
    if kill -TERM "$pid" 2>/dev/null; then
        print_status "Sent SIGTERM to process $pid"
        
        # Wait up to 10 seconds for graceful shutdown
        for i in {1..10}; do
            if ! ps -p "$pid" > /dev/null 2>&1; then
                print_status "Server stopped gracefully"
                return 0
            fi
            sleep 1
        done
        
        # If still running, force kill
        print_warning "Server didn't stop gracefully, forcing shutdown..."
        if kill -KILL "$pid" 2>/dev/null; then
            print_status "Server force-stopped"
            return 0
        else
            print_error "Failed to stop server process $pid"
            return 1
        fi
    else
        print_warning "Process $pid not found or already stopped"
        return 0
    fi
}

# Function to stop server by port
stop_server_by_port() {
    local port=$1
    print_status "Looking for process on port $port..."
    
    # Find process using the port
    PID=$(lsof -ti :$port 2>/dev/null || echo "")
    
    if [ -n "$PID" ]; then
        print_status "Found process $PID on port $port"
        stop_server_by_pid "$PID"
        return $?
    else
        print_status "No process found on port $port"
        return 0
    fi
}

# Function to cleanup files
cleanup_files() {
    print_status "Cleaning up server files..."
    
    # Remove PID file if it exists
    if [ -f "$PIDFILE" ]; then
        rm -f "$PIDFILE"
        print_status "Removed PID file"
    fi
    
    # Optionally clean up log file (ask user)
    if [ -f "$LOGFILE" ]; then
        read -p "Do you want to remove the log file ($LOGFILE)? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f "$LOGFILE"
            print_status "Removed log file"
        else
            print_status "Log file preserved: $LOGFILE"
        fi
    fi
}

# Function to show server status
show_server_status() {
    print_status "Server Status Check:"
    echo ""
    
    # Check PID file
    if [ -f "$PIDFILE" ]; then
        PID=$(cat "$PIDFILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            print_status "Server is running (PID: $PID)"
        else
            print_warning "PID file exists but process is not running"
        fi
    else
        print_status "No PID file found"
    fi
    
    # Check port
    if lsof -i :$SERVER_PORT > /dev/null 2>&1; then
        PORT_PID=$(lsof -ti :$SERVER_PORT 2>/dev/null || echo "")
        print_warning "Port $SERVER_PORT is in use (PID: $PORT_PID)"
    else
        print_status "Port $SERVER_PORT is free"
    fi
    
    # Check if server responds
    if curl -s "http://localhost:$SERVER_PORT/api/health" > /dev/null 2>&1; then
        print_warning "Server is responding to health checks"
    else
        print_status "Server is not responding"
    fi
}

# Main stop function
stop_server() {
    print_status "Stopping Piano Game Server..."
    
    local success=false
    
    # Method 1: Stop by PID file
    if [ -f "$PIDFILE" ]; then
        PID=$(cat "$PIDFILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            if stop_server_by_pid "$PID"; then
                success=true
            fi
        else
            print_warning "PID file exists but process $PID is not running"
        fi
    fi
    
    # Method 2: Stop by port (fallback)
    if ! $success; then
        if stop_server_by_port $SERVER_PORT; then
            success=true
        fi
    fi
    
    # Cleanup files
    cleanup_files
    
    if $success; then
        print_status "Server stopped successfully!"
    else
        print_error "Failed to stop server"
        exit 1
    fi
}

# Main execution
main() {
    echo "=================================================="
    echo "Piano Game Server - Stop Script"
    echo "=================================================="
    echo ""
    
    # Change to script directory
    cd "$(dirname "$0")"
    
    # Check if --status flag is provided
    if [[ "$1" == "--status" ]]; then
        show_server_status
        exit 0
    fi
    
    # Check if --force flag is provided
    if [[ "$1" == "--force" ]]; then
        print_warning "Force mode: Will kill all processes on port $SERVER_PORT"
        stop_server_by_port $SERVER_PORT
        cleanup_files
        exit 0
    fi
    
    stop_server
}

# Show usage if help is requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --status    Show current server status"
    echo "  --force     Force stop all processes on port $SERVER_PORT"
    echo "  --help      Show this help message"
    echo ""
    exit 0
fi

# Run main function
main "$@"