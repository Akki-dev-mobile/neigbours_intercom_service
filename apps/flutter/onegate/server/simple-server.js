const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 8080; // Using port 8080 which is commonly open

// In-memory storage for logs
const logs = [];

// Helper function to truncate large response bodies for display
const truncateIfNeeded = (str, maxLength = 1000) => {
  if (!str) return str;
  if (str.length <= maxLength) return str;
  return str.substring(0, maxLength) + '... (truncated)';
};

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Routes
app.get('/', (req, res) => {
  // HTML page with a simple viewer for the logs
  const html = `
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OneGate Network Logs</title>
    <style>
      body { font-family: Arial, sans-serif; margin: 0; padding: 20px; }
      h1 { color: #333; }
      .log-container { margin-top: 20px; }
      .log-item {
        border: 1px solid #ddd;
        border-radius: 4px;
        padding: 15px;
        margin-bottom: 15px;
        background-color: #f9f9f9;
      }
      .log-header {
        display: flex;
        justify-content: space-between;
        border-bottom: 1px solid #eee;
        padding-bottom: 10px;
        margin-bottom: 10px;
      }
      .method {
        font-weight: bold;
        padding: 3px 8px;
        border-radius: 3px;
        color: white;
      }
      .GET { background-color: #4CAF50; }
      .POST { background-color: #2196F3; }
      .PUT { background-color: #FF9800; }
      .DELETE { background-color: #F44336; }
      .PATCH { background-color: #9C27B0; }
      .status-2xx { color: #4CAF50; }
      .status-3xx { color: #2196F3; }
      .status-4xx { color: #F44336; }
      .status-5xx { color: #F44336; }
      .details { margin-top: 10px; }
      .tab {
        overflow: hidden;
        border: 1px solid #ccc;
        background-color: #f1f1f1;
        border-radius: 4px 4px 0 0;
      }
      .tab button {
        background-color: inherit;
        float: left;
        border: none;
        outline: none;
        cursor: pointer;
        padding: 10px 16px;
        transition: 0.3s;
      }
      .tab button:hover { background-color: #ddd; }
      .tab button.active { background-color: #ccc; }
      .tabcontent {
        display: none;
        padding: 15px;
        border: 1px solid #ccc;
        border-top: none;
        border-radius: 0 0 4px 4px;
        background-color: white;
      }
      pre {
        background-color: #f5f5f5;
        padding: 10px;
        border-radius: 4px;
        overflow: auto;
        max-height: 300px;
      }
      .refresh-btn {
        background-color: #4CAF50;
        color: white;
        padding: 10px 15px;
        border: none;
        border-radius: 4px;
        cursor: pointer;
        font-size: 16px;
      }
      .refresh-btn:hover { background-color: #45a049; }
    </style>
  </head>
  <body>
    <h1>OneGate Network Logs</h1>
    <p>View and analyze network logs from the OneGate app</p>

    <button class="refresh-btn" onclick="fetchLogs()">Refresh Logs</button>

    <div id="logs-container" class="log-container">
      <p>Loading logs...</p>
    </div>

    <script>
      // Fetch logs from the server
      function fetchLogs() {
        document.getElementById('logs-container').innerHTML = '<p>Loading logs...</p>';

        fetch('/logs')
          .then(response => response.json())
          .then(data => {
            if (data.logs.length === 0) {
              document.getElementById('logs-container').innerHTML = '<p>No logs available</p>';
              return;
            }

            let html = '';
            data.logs.forEach((log, index) => {
              const statusClass = getStatusClass(log.statusCode);
              const methodClass = log.method || 'GET';

              html += \`
                <div class="log-item">
                  <div class="log-header">
                    <div>
                      <span class="method \${methodClass}">\${log.method}</span>
                      <span style="margin-left: 10px;">\${log.url}</span>
                    </div>
                    <div>
                      <span class="\${statusClass}">\${log.statusCode || 'Error'}</span>
                      <span style="margin-left: 10px; color: #666;">\${formatDate(log.timestamp)}</span>
                    </div>
                  </div>

                  <div class="details">
                    <div class="tab">
                      <button class="tablinks" onclick="openTab(event, 'overview-\${index}')">Overview</button>
                      <button class="tablinks" onclick="openTab(event, 'request-\${index}')">Request</button>
                      <button class="tablinks" onclick="openTab(event, 'response-\${index}')">Response</button>
                    </div>

                    <div id="overview-\${index}" class="tabcontent">
                      <p><strong>ID:</strong> \${log.id}</p>
                      <p><strong>Method:</strong> \${log.method}</p>
                      <p><strong>URL:</strong> \${log.url}</p>
                      <p><strong>Status:</strong> <span class="\${statusClass}">\${log.statusCode || 'Error'}</span></p>
                      <p><strong>Duration:</strong> \${log.duration}ms</p>
                      <p><strong>Time:</strong> \${formatDate(log.timestamp)}</p>
                      <p><strong>Gate ID:</strong> \${log.gateId || 'Not specified'}</p>
                      <p><strong>Environment:</strong> \${log.environment || 'Not specified'}</p>
                      \${log.error ? \`<p><strong>Error:</strong> <span style="color: red;">\${log.error}</span></p>\` : ''}
                    </div>

                    <div id="request-\${index}" class="tabcontent">
                      <h3>Headers</h3>
                      <pre>\${formatJSON(log.headers)}</pre>

                      \${log.requestBody ? \`
                        <h3>Body</h3>
                        <pre>\${formatJSON(log.requestBody)}</pre>
                      \` : '<p>No request body</p>'}
                    </div>

                    <div id="response-\${index}" class="tabcontent">
                      \${log.error ? \`
                        <h3>Error</h3>
                        <pre style="color: red;">\${log.error}</pre>
                      \` : \`
                        <h3>Status Code</h3>
                        <p class="\${statusClass}">\${log.statusCode}</p>

                        <h3>Body</h3>
                        <pre>\${formatJSON(log.responseBody)}</pre>
                      \`}
                    </div>
                  </div>
                </div>
              \`;
            });

            document.getElementById('logs-container').innerHTML = html;

            // Open the first tab for each log
            document.querySelectorAll('.log-item').forEach((item, index) => {
              document.getElementById(\`overview-\${index}\`).style.display = 'block';
              item.querySelector('.tablinks').className += ' active';
            });
          })
          .catch(error => {
            document.getElementById('logs-container').innerHTML = \`<p>Error fetching logs: \${error.message}</p>\`;
          });
      }

      // Format date
      function formatDate(dateString) {
        if (!dateString) return 'Unknown';
        const date = new Date(dateString);
        return date.toLocaleString();
      }

      // Format JSON
      function formatJSON(json) {
        if (!json) return 'No data';
        try {
          if (typeof json === 'string') {
            // Try to parse as JSON
            const parsed = JSON.parse(json);
            return JSON.stringify(parsed, null, 2);
          } else {
            return JSON.stringify(json, null, 2);
          }
        } catch (e) {
          return json;
        }
      }

      // Get status class
      function getStatusClass(statusCode) {
        if (!statusCode) return 'status-5xx';
        if (statusCode >= 200 && statusCode < 300) return 'status-2xx';
        if (statusCode >= 300 && statusCode < 400) return 'status-3xx';
        if (statusCode >= 400 && statusCode < 500) return 'status-4xx';
        return 'status-5xx';
      }

      // Open tab
      function openTab(evt, tabName) {
        const tabcontent = document.getElementsByClassName('tabcontent');
        for (let i = 0; i < tabcontent.length; i++) {
          if (tabcontent[i].id.split('-')[0] === tabName.split('-')[0]) {
            tabcontent[i].style.display = 'none';
          }
        }

        const tablinks = evt.currentTarget.parentElement.getElementsByClassName('tablinks');
        for (let i = 0; i < tablinks.length; i++) {
          tablinks[i].className = tablinks[i].className.replace(' active', '');
        }

        document.getElementById(tabName).style.display = 'block';
        evt.currentTarget.className += ' active';
      }

      // Fetch logs on page load
      document.addEventListener('DOMContentLoaded', fetchLogs);
    </script>
  </body>
  </html>
  `;

  res.send(html);
});

// Get all logs
app.get('/logs', (req, res) => {
  try {
    const { gateId, environment, limit = 100, page = 1 } = req.query;

    let filteredLogs = [...logs];

    // Apply filters
    if (gateId) {
      filteredLogs = filteredLogs.filter(log => log.gateId === gateId);
    }

    if (environment) {
      filteredLogs = filteredLogs.filter(log => log.environment === environment);
    }

    // Sort by timestamp (newest first)
    filteredLogs.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

    // Paginate
    const total = filteredLogs.length;
    const skip = (page - 1) * limit;
    const paginatedLogs = filteredLogs.slice(skip, skip + parseInt(limit));

    res.json({
      logs: paginatedLogs,
      pagination: {
        total,
        page: parseInt(page),
        limit: parseInt(limit),
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    console.error('Error fetching logs:', error);
    res.status(500).json({ error: 'Failed to fetch logs' });
  }
});

// Post logs
app.post('/logs', (req, res) => {
  try {
    const { logs: newLogs } = req.body;

    if (!newLogs || !Array.isArray(newLogs) || newLogs.length === 0) {
      return res.status(400).json({ error: 'Invalid logs data' });
    }

    console.log(`Received ${newLogs.length} logs`);

    // Process each log
    for (const log of newLogs) {
      // Process and potentially truncate large request/response bodies
      const processedLog = {
        ...log,
        requestBody: truncateIfNeeded(log.requestBody),
        responseBody: truncateIfNeeded(log.responseBody),
        createdAt: new Date()
      };

      const existingIndex = logs.findIndex(l => l.id === log.id);
      if (existingIndex !== -1) {
        // Update existing log
        logs[existingIndex] = processedLog;
      } else {
        // Add new log
        logs.push(processedLog);
      }

      // Log details about the received log
      console.log(`Log ID: ${log.id}, Method: ${log.method}, URL: ${log.url}, Status: ${log.statusCode || 'Error'}`);
    }

    // Keep only the latest 1000 logs to prevent memory issues
    if (logs.length > 1000) {
      logs.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
      logs.length = 1000;
    }

    res.status(201).json({
      message: 'Logs saved successfully',
      inserted: newLogs.length,
      total: logs.length
    });
  } catch (error) {
    console.error('Error saving logs:', error);
    res.status(500).json({ error: 'Failed to save logs' });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`Simple server running on port ${PORT}`);
  console.log(`No database connection required`);
  console.log(`Access the server at http://localhost:${PORT}`);
  console.log(`Access logs at http://localhost:${PORT}/logs`);
});
