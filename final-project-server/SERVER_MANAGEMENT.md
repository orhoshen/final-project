# Piano Game Server Management

This directory contains robust server management scripts for development and deployment.

## Quick Start

```bash
# Start the server
./start_server.sh

# Stop the server
./stop_server.sh

# Check server status
./server_manager.sh status

# View logs
./server_manager.sh logs
```

## Scripts Overview

### 1. `start_server.sh`
**Purpose**: Robust server startup with comprehensive checks and error handling.

**Features**:
- Checks for existing server processes
- Handles port conflicts automatically
- Activates virtual environment if available
- Installs dependencies automatically
- Runs health checks after startup
- Provides detailed status information

**Usage**:
```bash
./start_server.sh
```

**What it does**:
1. Checks if server is already running
2. Verifies port 5001 is available
3. Activates virtual environment (.venv or venv)
4. Installs/updates dependencies from requirements.txt
5. Starts server in background with proper logging
6. Saves PID to server.pid file
7. Performs health check
8. Shows server information

### 2. `stop_server.sh`
**Purpose**: Graceful server shutdown with proper cleanup.

**Features**:
- Graceful shutdown with SIGTERM
- Force shutdown with SIGKILL if needed
- Cleanup of PID files
- Optional log file cleanup
- Multiple stop methods (PID file, port lookup)

**Usage**:
```bash
./stop_server.sh                # Normal stop
./stop_server.sh --force        # Force stop all processes on port
./stop_server.sh --status       # Show server status
./stop_server.sh --help         # Show help
```

**What it does**:
1. Attempts graceful shutdown (SIGTERM)
2. Waits up to 10 seconds for clean exit
3. Force kills if necessary (SIGKILL)
4. Cleans up PID files
5. Optionally removes log files

### 3. `server_manager.sh`
**Purpose**: Comprehensive server management with multiple commands.

**Features**:
- Multiple management commands
- Status monitoring
- Log viewing
- Health checking
- Dependency management
- File cleanup

**Usage**:
```bash
./server_manager.sh <command> [options]
```

**Commands**:
- `start` - Start the server
- `stop` - Stop the server
- `restart` - Restart the server
- `status` - Show detailed server status
- `logs` - Show server logs
- `health` - Check server health
- `install` - Install dependencies
- `clean` - Clean up server files
- `help` - Show help

**Examples**:
```bash
./server_manager.sh start              # Start server
./server_manager.sh stop --force       # Force stop
./server_manager.sh logs --follow      # Follow logs
./server_manager.sh restart            # Restart server
./server_manager.sh status             # Show status
./server_manager.sh health             # Health check
./server_manager.sh install            # Install deps
./server_manager.sh clean --force      # Clean files
```

## File Structure

```
final-project-server/
├── start_server.sh          # Server startup script
├── stop_server.sh           # Server shutdown script
├── server_manager.sh        # Comprehensive management script
├── server.pid               # Process ID file (created at runtime)
├── server.log               # Server log file (created at runtime)
├── simple_app.py           # Main server application
├── requirements.txt        # Python dependencies
└── .venv/ or venv/         # Virtual environment (optional)
```

## Development Workflow

### Daily Development
```bash
# Start server for development
./start_server.sh

# Check if everything is working
./server_manager.sh status

# View logs during development
./server_manager.sh logs --follow

# Restart after code changes
./server_manager.sh restart

# Stop when done
./stop_server.sh
```

### Troubleshooting
```bash
# Check server status
./server_manager.sh status

# Check server health
./server_manager.sh health

# View recent logs
./server_manager.sh logs

# Force stop if server is stuck
./stop_server.sh --force

# Clean up files and restart
./server_manager.sh clean --force
./start_server.sh
```

### Installation/Setup
```bash
# Install dependencies
./server_manager.sh install

# Or manually with virtual environment
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Configuration

### Environment Variables
The server uses these environment variables:
- `PORT` - Server port (default: 5001)
- `FLASK_ENV` - Flask environment (default: development)
- `SECRET_KEY` - Flask secret key

### Script Configuration
Edit the configuration section in each script:
```bash
# Configuration
SERVER_PORT=5001
PIDFILE="server.pid"
LOGFILE="server.log"
PYTHON_CMD="python3"
```

## Error Handling

### Common Issues and Solutions

**Port Already in Use**:
```bash
# Check what's using the port
lsof -i :5001

# Force stop all processes on port
./stop_server.sh --force
```

**Server Won't Start**:
```bash
# Check logs for errors
./server_manager.sh logs

# Clean up and try again
./server_manager.sh clean --force
./start_server.sh
```

**Dependencies Missing**:
```bash
# Install dependencies
./server_manager.sh install
```

**Server Appears Running but Not Responding**:
```bash
# Check health
./server_manager.sh health

# Check status
./server_manager.sh status

# Force restart
./server_manager.sh clean --force
./start_server.sh
```

## Deployment Considerations

### Production Deployment
For production deployment, consider:
1. Use a proper WSGI server (gunicorn, uWSGI)
2. Set up proper logging
3. Use environment-specific configuration
4. Implement health checks
5. Set up monitoring

### Google Cloud App Engine
This server is configured for Google Cloud App Engine deployment:
```bash
# Deploy to Google Cloud
gcloud app deploy
```

The `app.yaml` file contains the deployment configuration.

## Monitoring

### Health Checks
The server provides a health endpoint at `/api/health`:
```bash
curl http://localhost:5001/api/health
```

### Log Monitoring
```bash
# View logs in real-time
./server_manager.sh logs --follow

# View recent logs
./server_manager.sh logs
```

### Status Monitoring
```bash
# Detailed status
./server_manager.sh status

# Quick health check
./server_manager.sh health
```

## Security Notes

1. **Development Only**: These scripts are designed for development
2. **Port Security**: Server binds to all interfaces (0.0.0.0)
3. **Log Files**: May contain sensitive information
4. **Process Management**: Scripts require proper permissions

## Support

For issues with the server management scripts:
1. Check the logs: `./server_manager.sh logs`
2. Verify status: `./server_manager.sh status`
3. Try force restart: `./server_manager.sh clean --force && ./start_server.sh`
4. Check port availability: `lsof -i :5001`

---

*Generated for Piano Game Server Management System*