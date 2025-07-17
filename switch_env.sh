#!/bin/bash

# Script to switch between development and production environments

if [ "$1" = "production" ]; then
    if [ -f ".env.production" ]; then
        cp .env.production .env
        echo "Switched to production environment"
        echo "Server URL: $(grep FLASK_SERVER_URL .env | cut -d'=' -f2)"
    else
        echo "Error: .env.production file not found"
        exit 1
    fi
elif [ "$1" = "development" ] || [ "$1" = "dev" ]; then
    # Reset to development environment
    cat > .env << 'EOF'
# Server Configuration
# For local development, use localhost
# For production, replace with your deployed server URL
FLASK_SERVER_URL=http://localhost:5001
FLASK_SERVER_HOST=localhost
FLASK_SERVER_PORT=5001
FLASK_SERVER_FALLBACK_HOST=127.0.0.1

# Production server URL (uncomment and update after deployment)
# FLASK_SERVER_URL=https://YOUR_PROJECT_ID.appspot.com

# Local development settings
AUTO_START_SERVER=false
SERVER_RETRY_COUNT=5
SERVER_HEALTH_CHECK_INTERVAL=30
EOF
    echo "Switched to development environment"
    echo "Server URL: $(grep FLASK_SERVER_URL .env | cut -d'=' -f2)"
else
    echo "Usage: $0 [production|development]"
    echo "Current environment:"
    echo "Server URL: $(grep FLASK_SERVER_URL .env | cut -d'=' -f2)"
    exit 1
fi