# Deployment Guide

## Google Cloud App Engine Deployment

### Prerequisites
- Google Cloud SDK installed
- Google Cloud project with App Engine enabled
- Billing enabled on your project

### Step-by-Step Deployment

1. **Login to Google Cloud**:
   ```bash
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   ```

2. **Verify App Engine is enabled**:
   ```bash
   gcloud app describe
   ```
   If not enabled, create an App Engine application:
   ```bash
   gcloud app create --region=us-central1
   ```

3. **Deploy the application**:
   ```bash
   gcloud app deploy
   ```

4. **View the deployed application**:
   ```bash
   gcloud app browse
   ```

### Environment Configuration

The server will be available at:
- **Production URL**: `https://YOUR_PROJECT_ID.appspot.com`
- **Health Check**: `https://YOUR_PROJECT_ID.appspot.com/api/health`

### Client Configuration

After deployment, update your client application's server URL:

1. **For Flutter client**: Update the `.env` file:
   ```
   FLASK_SERVER_URL=https://YOUR_PROJECT_ID.appspot.com
   ```

2. **For other clients**: Update the base URL in your HTTP requests and WebSocket connections.

### Monitoring and Logs

- **View logs**: `gcloud app logs tail -s default`
- **App Engine Console**: https://console.cloud.google.com/appengine
- **Cloud Logging**: https://console.cloud.google.com/logs

### Scaling Configuration

The `app.yaml` file includes automatic scaling:
- **Target CPU**: 65%
- **Min instances**: 1
- **Max instances**: 10

Adjust these values in `app.yaml` as needed for your traffic patterns.

### Security Notes

- The server uses HTTPS by default on App Engine
- CORS is configured to allow cross-origin requests
- Session affinity is enabled for WebSocket connections
- No sensitive data is logged in production mode

### Troubleshooting

**Common deployment issues**:

1. **Build fails**: Check that all dependencies are in `requirements.txt`
2. **WebSocket issues**: Ensure `eventlet` is installed and specified in entrypoint
3. **Timeout errors**: Increase instance class or adjust scaling parameters

**Debugging steps**:
1. Check logs: `gcloud app logs tail -s default`
2. Verify health endpoint: `curl https://YOUR_PROJECT_ID.appspot.com/api/health`
3. Test WebSocket connection from client
4. Monitor App Engine metrics in Cloud Console

### Cost Management

- **Free tier**: App Engine has a generous free tier
- **Scaling**: Configure min/max instances based on usage
- **Monitoring**: Set up billing alerts to monitor costs

For detailed pricing information, visit: https://cloud.google.com/appengine/pricing