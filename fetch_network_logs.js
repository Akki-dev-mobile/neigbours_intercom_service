const axios = require('axios');
const fs = require('fs');

// Configuration
const config = {
  serverUrl: 'http://localhost:3000/logs', // Default server URL
  outputFile: 'network_logs.json',
  filters: {
    gateId: null,      // e.g., 'MAIN_GATE'
    environment: null, // e.g., 'dev', 'staging', 'prod'
    limit: 100,
    page: 1
  }
};

// Parse command line arguments
process.argv.slice(2).forEach(arg => {
  const [key, value] = arg.split('=');
  if (key === 'serverUrl') {
    config.serverUrl = value;
  } else if (key === 'outputFile') {
    config.outputFile = value;
  } else if (key === 'gateId') {
    config.filters.gateId = value;
  } else if (key === 'environment') {
    config.filters.environment = value;
  } else if (key === 'limit') {
    config.filters.limit = parseInt(value);
  } else if (key === 'page') {
    config.filters.page = parseInt(value);
  }
});

// Build query string
const queryParams = [];
if (config.filters.gateId) queryParams.push(`gateId=${config.filters.gateId}`);
if (config.filters.environment) queryParams.push(`environment=${config.filters.environment}`);
if (config.filters.limit) queryParams.push(`limit=${config.filters.limit}`);
if (config.filters.page) queryParams.push(`page=${config.filters.page}`);

const url = `${config.serverUrl}${queryParams.length > 0 ? '?' + queryParams.join('&') : ''}`;

console.log(`Fetching network logs from: ${url}`);

// Fetch logs
axios.get(url)
  .then(response => {
    const data = response.data;
    console.log(`Retrieved ${data.logs.length} logs (Total: ${data.pagination.total})`);
    
    // Save to file
    fs.writeFileSync(config.outputFile, JSON.stringify(data, null, 2));
    console.log(`Logs saved to ${config.outputFile}`);
    
    // Print summary
    console.log('\nLog Summary:');
    const methods = {};
    const statusCodes = {};
    const gates = {};
    
    data.logs.forEach(log => {
      // Count methods
      methods[log.method] = (methods[log.method] || 0) + 1;
      
      // Count status codes
      if (log.statusCode) {
        statusCodes[log.statusCode] = (statusCodes[log.statusCode] || 0) + 1;
      } else {
        statusCodes['error'] = (statusCodes['error'] || 0) + 1;
      }
      
      // Count gates
      gates[log.gateId] = (gates[log.gateId] || 0) + 1;
    });
    
    console.log('Methods:', methods);
    console.log('Status Codes:', statusCodes);
    console.log('Gates:', gates);
    
    // Print pagination info
    console.log('\nPagination:');
    console.log(`Page ${data.pagination.page} of ${data.pagination.pages}`);
    console.log(`Showing ${data.logs.length} of ${data.pagination.total} logs`);
    
    if (data.pagination.page < data.pagination.pages) {
      console.log(`\nTo see the next page, run:`);
      console.log(`node fetch_network_logs.js serverUrl=${config.serverUrl} page=${data.pagination.page + 1}`);
    }
  })
  .catch(error => {
    console.error('Error fetching logs:', error.message);
    if (error.response) {
      console.error('Response status:', error.response.status);
      console.error('Response data:', error.response.data);
    }
  });
