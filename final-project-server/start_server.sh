#!/bin/bash
# Piano Game Server - Start Script
# This script provides robust server startup with proper process management

set -e  # Exit on any error

# Configuration
SERVER_PORT=5001
PIDFILE="server.pid"
LOGFILE="server.log"
PYTHON_CMD="python3"

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

# Function to check if server is already running
check_server_running() {
    if [ -f "$PIDFILE" ]; then
        PID=$(cat "$PIDFILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            return 0  # Server is running
        else
            # PID file exists but process is dead - clean up
            rm -f "$PIDFILE"
            return 1  # Server is not running
        fi
    else
        return 1  # Server is not running
    fi
}

# Function to check if port is available
check_port_available() {
    if lsof -i :$SERVER_PORT > /dev/null 2>&1; then
        return 1  # Port is occupied
    else
        return 0  # Port is available
    fi
}

# Function to find and kill process on port
kill_process_on_port() {
    local port=$1
    print_warning "Finding process on port $port..."
    
    # Find process using the port
    PID=$(lsof -ti :$port 2>/dev/null || echo "")
    
    if [ -n "$PID" ]; then
        print_warning "Killing process $PID on port $port"
        kill -9 "$PID" 2>/dev/null || true
        sleep 2
        
        # Verify process is killed
        if lsof -i :$port > /dev/null 2>&1; then
            print_error "Failed to kill process on port $port"
            return 1
        else
            print_status "Process on port $port killed successfully"
            return 0
        fi
    else
        print_status "No process found on port $port"
        return 0
    fi
}

# Function to start the server
start_server() {
    print_status "Starting Piano Game Server..."
    
    # Check if server is already running
    if check_server_running; then
        PID=$(cat "$PIDFILE")
        print_warning "Server is already running with PID $PID"
        print_status "Server URL: http://localhost:$SERVER_PORT"
        return 0
    fi
    
    # Check if port is available
    if ! check_port_available; then
        print_warning "Port $SERVER_PORT is occupied"
        read -p "Do you want to kill the process using port $SERVER_PORT? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if ! kill_process_on_port $SERVER_PORT; then
                print_error "Failed to free port $SERVER_PORT"
                exit 1
            fi
        else
            print_error "Cannot start server - port $SERVER_PORT is occupied"
            exit 1
        fi
    fi
    
    # Check if Python is available
    if ! command -v $PYTHON_CMD &> /dev/null; then
        print_error "Python3 not found. Please install Python3."
        exit 1
    fi
    
    # Check if virtual environment exists
    if [ -d ".venv" ]; then
        print_status "Activating virtual environment..."
        source .venv/bin/activate
    elif [ -d "venv" ]; then
        print_status "Activating virtual environment..."
        source venv/bin/activate
    else
        print_warning "No virtual environment found. Using system Python."
    fi
    
    # Install dependencies if requirements.txt exists
    if [ -f "requirements.txt" ]; then
        print_status "Installing/updating dependencies..."
        pip install -r requirements.txt > /dev/null 2>&1
    fi
    
    # Start the server in background
    print_status "Starting server on port $SERVER_PORT..."
    
    # Set environment variables
    export PORT=$SERVER_PORT
    export FLASK_ENV=development
    
    # Start server and capture PID
    nohup $PYTHON_CMD simple_app.py > "$LOGFILE" 2>&1 &
    SERVER_PID=$!
    
    # Save PID to file
    echo $SERVER_PID > "$PIDFILE"
    
    # Wait a moment and check if server started successfully
    sleep 3
    
    if ps -p $SERVER_PID > /dev/null 2>&1; then
        print_status "Server started successfully!"
        print_status "PID: $SERVER_PID"
        print_status "Port: $SERVER_PORT"
        print_status "URL: http://localhost:$SERVER_PORT"
        print_status "Logs: $LOGFILE"
        print_status ""
        print_status "To stop the server, run: ./stop_server.sh"
        print_status "To view logs, run: tail -f $LOGFILE"
        
        # Test server health
        sleep 2
        if curl -s "http://localhost:$SERVER_PORT/api/health" > /dev/null 2>&1; then
            print_status "Server health check: PASSED"
        else
            print_warning "Server health check: FAILED (server may still be starting)"
        fi
    else
        print_error "Failed to start server"
        rm -f "$PIDFILE"
        exit 1
    fi
}

# Main execution
main() {
    echo "=================================================="
    echo "Piano Game Server - Start Script"
    echo "=================================================="
    echo ""
    
    # Change to script directory
    cd "$(dirname "$0")"
    
    start_server
}

# Run main function
main "$@"