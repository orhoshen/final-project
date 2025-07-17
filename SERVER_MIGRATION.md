# Server Migration Guide

## Overview

The Piano Game Server has been moved to a separate repository for better deployment architecture and maintenance. This document outlines the migration process and new setup.

## What Changed

### Before (Monorepo)
- Server code was in `final-project-server/` directory
- Client and server were in the same repository
- Local development required running both from the same codebase

### After (Separate Repositories)
- **Client**: This repository (piano_game_consolidated)
- **Server**: https://github.com/AlonHermoni/final-project-server
- Independent deployment and development cycles

## Migration Steps Completed

1. ✅ **Server Code Preparation**: Updated server code with deployment configuration
2. ✅ **Environment Configuration**: Added environment switching for production/development
3. ✅ **Documentation Updates**: Updated README with new architecture instructions
4. ✅ **Client Configuration**: Modified client to use environment variables for server URL

## Next Steps for Full Migration

1. **Copy Server to Separate Repository**:
   ```bash
   # In the server repository
   cp -r /path/to/piano_game_consolidated/final-project-server/* .
   git add .
   git commit -m "Initial server deployment setup"
   git push origin main
   ```

2. **Deploy Server to Google Cloud**:
   ```bash
   # In the server repository
   gcloud app deploy
   ```

3. **Update Client Configuration**:
   ```bash
   # In the client repository
   # Edit .env.production with your actual project ID
   ./switch_env.sh production
   ```

4. **Remove Server from Client Repository**:
   ```bash
   # In the client repository
   rm -rf final-project-server/
   git add .
   git commit -m "Remove server code (moved to separate repository)"
   ```

## Environment Management

### Development Environment
- Uses `http://localhost:5001` (local server)
- Switch with: `./switch_env.sh development`

### Production Environment
- Uses `https://YOUR_PROJECT_ID.appspot.com` (deployed server)
- Switch with: `./switch_env.sh production`

### Check Current Environment
```bash
./switch_env.sh
```

## Benefits of Separate Repository

1. **Independent Deployment**: Client and server can be deployed separately
2. **Team Collaboration**: Different teams can work on client vs server
3. **CI/CD**: Separate build and deployment pipelines
4. **Scaling**: Server can be scaled independently
5. **Security**: Different access controls and secrets management

## Files Modified

### Client Repository (this repo)
- `.env` - Updated with production server configuration
- `.env.production` - Production environment configuration
- `switch_env.sh` - Environment switching script
- `README.md` - Updated setup instructions
- `SERVER_MIGRATION.md` - This migration guide

### Server Repository (separate)
- `.gitignore` - Enhanced for server deployment
- `README.md` - Updated for standalone server
- `DEPLOYMENT.md` - Google Cloud deployment guide
- All server files preserved and deployment-ready

## Rollback Process

If you need to rollback to the monorepo structure:

1. Copy server code back to `final-project-server/`
2. Revert `.env` to localhost configuration
3. Update README to reference local server setup
4. Remove environment switching scripts

## Support

For issues related to:
- **Client**: Use this repository's issues
- **Server**: Use the server repository's issues
- **Deployment**: Check the server repository's DEPLOYMENT.md