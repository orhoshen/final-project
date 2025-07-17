#!/bin/bash
# Piano Game Server - Management Script
# This script provides comprehensive server management for development and deployment

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
BLUE='\033[0;34m'
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

print_header() {
    echo -e "${BLUE}[HEADER]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Piano Game Server Management Script"
    echo "====================================="
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start         Start the server"
    echo "  stop          Stop the server"
    echo "  restart       Restart the server"
    echo "  status        Show server status"
    echo "  logs          Show server logs"
    echo "  health        Check server health"
    echo "  install       Install dependencies"
    echo "  clean         Clean up server files"
    echo "  help          Show this help message"
    echo ""
    echo "Options:"
    echo "  --force       Force operation (for stop/clean)"
    echo "  --follow      Follow logs in real-time"
    echo "  --port <port> Use custom port (default: $SERVER_PORT)"
    echo ""
    echo "Examples:"
    echo "  $0 start              # Start the server"
    echo "  $0 stop --force       # Force stop the server"
    echo "  $0 logs --follow      # Follow logs in real-time"
    echo "  $0 restart            # Restart the server"
    echo "  $0 health             # Check server health"
    echo ""
}

# Function to check if server is running
is_server_running() {
    if [ -f "$PIDFILE" ]; then
        PID=$(cat "$PIDFILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            return 0  # Server is running
        else
            rm -f "$PIDFILE"  # Clean up stale PID file
            return 1  # Server is not running
        fi
    else
        return 1  # Server is not running
    fi
}

# Function to get server PID
get_server_pid() {
    if [ -f "$PIDFILE" ]; then
        cat "$PIDFILE"
    else
        echo ""
    fi
}

# Function to check server health
check_server_health() {
    local url="http://localhost:$SERVER_PORT/api/health"
    local response=$(curl -s -w "%{http_code}" -o /dev/null "$url" 2>/dev/null || echo "000")
    
    if [ "$response" = "200" ]; then
        return 0  # Healthy
    else
        return 1  # Unhealthy
    fi
}

# Function to show server status
show_status() {
    print_header "Server Status"
    echo ""
    
    # Check process status
    if is_server_running; then
        PID=$(get_server_pid)
        print_status "Server is running (PID: $PID)"
        
        # Check memory usage
        if command -v ps &> /dev/null; then
            MEM=$(ps -o rss= -p "$PID" 2>/dev/null || echo "0")
            MEM_MB=$((MEM / 1024))
            print_status "Memory usage: ${MEM_MB}MB"
        fi
        
        # Check port status
        if lsof -i :$SERVER_PORT > /dev/null 2>&1; then
            print_status "Port $SERVER_PORT is in use"
        else
            print_warning "Process running but port $SERVER_PORT is not bound"
        fi
        
        # Check health
        if check_server_health; then
            print_status "Health check: PASSED"
        else
            print_warning "Health check: FAILED"
        fi
        
        # Show uptime
        if command -v ps &> /dev/null; then
            UPTIME=$(ps -o etime= -p "$PID" 2>/dev/null | tr -d ' ' || echo "unknown")
            print_status "Uptime: $UPTIME"
        fi
    else
        print_status "Server is not running"
        
        # Check if port is occupied by another process
        if lsof -i :$SERVER_PORT > /dev/null 2>&1; then
            PORT_PID=$(lsof -ti :$SERVER_PORT 2>/dev/null || echo "")
            print_warning "Port $SERVER_PORT is occupied by another process (PID: $PORT_PID)"
        fi
    fi
    
    # Show log file info
    if [ -f "$LOGFILE" ]; then
        LOG_SIZE=$(du -h "$LOGFILE" 2>/dev/null | cut -f1 || echo "unknown")
        print_status "Log file: $LOGFILE (Size: $LOG_SIZE)"
    else
        print_status "No log file found"
    fi
}

# Function to install dependencies
install_dependencies() {
    print_header "Installing Dependencies"
    
    # Check if requirements.txt exists
    if [ ! -f "requirements.txt" ]; then
        print_error "requirements.txt not found"
        exit 1
    fi
    
    # Check if virtual environment exists
    if [ -d ".venv" ]; then
        print_status "Using virtual environment: .venv"
        source .venv/bin/activate
    elif [ -d "venv" ]; then
        print_status "Using virtual environment: venv"
        source venv/bin/activate
    else
        print_warning "No virtual environment found. Consider creating one:"
        print_warning "  python3 -m venv .venv"
        print_warning "  source .venv/bin/activate"
    fi
    
    # Install dependencies
    print_status "Installing dependencies..."
    pip install -r requirements.txt
    
    print_status "Dependencies installed successfully"
}

# Function to show logs
show_logs() {
    local follow_logs=false
    
    # Check for --follow flag
    if [[ "$1" == "--follow" ]]; then
        follow_logs=true
    fi
    
    if [ ! -f "$LOGFILE" ]; then
        print_error "Log file not found: $LOGFILE"
        exit 1
    fi
    
    if $follow_logs; then
        print_status "Following logs (Press Ctrl+C to stop)..."
        tail -f "$LOGFILE"
    else
        print_status "Showing last 50 lines of logs..."
        tail -n 50 "$LOGFILE"
    fi
}

# Function to clean up server files
clean_server() {
    local force=false
    
    # Check for --force flag
    if [[ "$1" == "--force" ]]; then
        force=true
    fi
    
    print_header "Cleaning Server Files"
    
    # Stop server if running
    if is_server_running; then
        if $force; then
            print_status "Stopping server..."
            ./stop_server.sh --force
        else
            print_error "Server is running. Stop it first or use --force"
            exit 1
        fi
    fi
    
    # Remove files
    local files_to_remove=("$PIDFILE" "$LOGFILE" "*.pyc" "__pycache__")
    
    for file in "${files_to_remove[@]}"; do
        if [ -f "$file" ] || [ -d "$file" ]; then
            rm -rf "$file"
            print_status "Removed: $file"
        fi
    done
    
    # Remove Python cache directories
    find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    find . -name "*.pyc" -type f -delete 2>/dev/null || true
    
    print_status "Cleanup completed"
}

# Function to check health
check_health() {
    print_header "Health Check"
    
    if ! is_server_running; then
        print_error "Server is not running"
        exit 1
    fi
    
    local url="http://localhost:$SERVER_PORT/api/health"
    print_status "Checking: $url"
    
    local response=$(curl -s "$url" 2>/dev/null || echo "")
    
    if [ -n "$response" ]; then
        print_status "Response: $response"
        
        if echo "$response" | grep -q "healthy"; then
            print_status "Health check: PASSED"
            exit 0
        else
            print_error "Health check: FAILED"
            exit 1
        fi
    else
        print_error "No response from server"
        exit 1
    fi
}

# Main function
main() {
    # Change to script directory
    cd "$(dirname "$0")"
    
    # Parse arguments
    local command="$1"
    local option="$2"
    
    case "$command" in
        "start")
            ./start_server.sh
            ;;
        "stop")
            ./stop_server.sh $option
            ;;
        "restart")
            print_header "Restarting Server"
            ./stop_server.sh
            sleep 2
            ./start_server.sh
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs $option
            ;;
        "health")
            check_health
            ;;
        "install")
            install_dependencies
            ;;
        "clean")
            clean_server $option
            ;;
        "help"|"--help"|"-h"|"")
            show_usage
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"