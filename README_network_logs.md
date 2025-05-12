# Network Logs Viewer

This guide explains how to access and view the network logs stored on the remote server for the OneGate app.

## Overview

The OneGate app captures network logs (API requests and responses) and syncs them to a remote server. These logs are stored in a MongoDB database and can be accessed through a REST API.

## Server Configuration

The network logs server is a Node.js application with the following components:

- **Server**: Express.js
- **Database**: MongoDB
- **Default URL**: `http://localhost:3000/logs`
- **Default MongoDB URI**: `mongodb://localhost:27017/onegate-logs`

## Accessing the Logs

### Option 1: Using the API Directly

You can access the logs directly through the server's REST API:

```bash
# Get all logs
curl http://localhost:3000/logs

# Filter logs by gate ID
curl http://localhost:3000/logs?gateId=MAIN_GATE

# Filter logs by environment
curl http://localhost:3000/logs?environment=dev

# Limit and paginate results
curl http://localhost:3000/logs?limit=50&page=2
```

### Option 2: Using the Provided Script

We've created a script to help you fetch and analyze the logs:

1. Make sure you have Node.js installed
2. Install the required dependencies:
   ```bash
   npm install axios
   ```
3. Run the script:
   ```bash
   node fetch_network_logs.js
   ```

#### Script Options

You can customize the script behavior with command-line arguments:

```bash
# Specify a different server URL
node fetch_network_logs.js serverUrl=http://your-server-url.com/logs

# Filter by gate ID
node fetch_network_logs.js gateId=MAIN_GATE

# Filter by environment
node fetch_network_logs.js environment=dev

# Change the output file
node fetch_network_logs.js outputFile=my_logs.json

# Limit and paginate results
node fetch_network_logs.js limit=50 page=2

# Combine multiple options
node fetch_network_logs.js serverUrl=http://your-server-url.com/logs gateId=MAIN_GATE environment=dev limit=50 page=1
```

### Option 3: Using MongoDB Compass

If you have direct access to the MongoDB database, you can use MongoDB Compass to view and query the logs:

1. Download and install [MongoDB Compass](https://www.mongodb.com/products/compass)
2. Connect to the MongoDB server using the connection string (e.g., `mongodb://localhost:27017`)
3. Select the `onegate-logs` database
4. Open the `networklogs` collection
5. Use the query interface to filter and view logs

## Log Schema

Each log entry contains the following fields:

- `id`: Unique identifier for the log
- `url`: The URL of the request
- `method`: HTTP method (GET, POST, etc.)
- `statusCode`: HTTP status code of the response
- `timestamp`: When the request was made
- `duration`: How long the request took (in milliseconds)
- `gateId`: Identifier for the gate (e.g., "MAIN_GATE")
- `environment`: Environment (dev, staging, prod)
- `error`: Error message (if any)
- `createdAt`: When the log was created in the database

## Troubleshooting

If you're having trouble accessing the logs:

1. **Check the server URL**: Make sure the server URL in the app's Network Log Sync Settings is correct
2. **Verify the server is running**: The Node.js server needs to be running to access the logs
3. **Check MongoDB connection**: The server needs to be able to connect to MongoDB
4. **Check network connectivity**: Make sure your device can reach the server

## Additional Information

For more details about the network logging system, refer to the following files in the codebase:

- `apps/flutter/onegate/lib/utils/network_log/README.md`
- `apps/flutter/onegate/server/server.js`
- `apps/flutter/onegate/lib/utils/network_log/services/network_log_sync_service.dart`
