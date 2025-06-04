# OneGate Real-time Web Dashboard Integration Guide

## 🎯 **Overview**

This guide shows you how to connect your OneGate Flutter app to display **real live data** in the web dashboard instead of simulated data.

## 🚀 **Quick Start - See Real Data Now!**

### **Step 1: Start the API Server**
```bash
cd apps/flutter/onegate
python3 web/realtime_api_server.py
```

### **Step 2: Access the Web Dashboard**
Open your browser to: **http://localhost:9999**

### **Step 3: Initialize Web Bridge in Flutter App**

Add this code to your OneGate Flutter app's main initialization:

```dart
import 'package:flutter_onegate/services/observatory/web_dashboard_bridge.dart';

// In your main() function or app initialization
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the web dashboard bridge
  final webBridge = WebDashboardBridge();
  await webBridge.initialize();
  
  runApp(MyApp());
}
```

### **Step 4: Verify Real-time Connection**

1. **Check Connection Status**: Look for the green "🟢 Connected to Real-time API" indicator at the top of the web dashboard
2. **Watch Live Updates**: Metrics should update every 5 seconds with real data from your Flutter app
3. **View Real Logs**: Recent logs from your app will appear in the logs section

## 📊 **What Metrics Are Displayed**

### **Network Metrics**
- **Total Requests**: Count of all network requests made by the app
- **Successful Requests**: Requests with 2xx status codes
- **Failed Requests**: Requests with 4xx/5xx status codes  
- **Average Response Time**: Mean response time in milliseconds

### **Error Tracking**
- **Total Crashes**: Number of app crashes detected
- **Fatal Crashes**: Critical crashes that terminated the app
- **Handled Exceptions**: Caught exceptions that were handled gracefully
- **Error Rate**: Percentage of failed requests vs total requests

### **Analytics Data**
- **Total Events**: Number of user interaction events tracked
- **Active Users**: Current number of active users
- **Session Duration**: Average user session length
- **App Version**: Current version of the OneGate app

### **System Status**
- **Observatory Service**: Status of the monitoring service
- **Data Collection**: Whether metrics collection is active
- **WebSocket Connection**: Real-time connection status
- **Last Update**: Timestamp of the most recent data update

## 🔧 **Configuration Options**

### **Custom API URL**
```dart
final webBridge = WebDashboardBridge();
await webBridge.initialize(apiUrl: 'http://your-server:8866/api');
```

### **Custom Update Interval**
```dart
await webBridge.startDataTransmission(
  interval: Duration(seconds: 10), // Update every 10 seconds
);
```

### **Send Custom Metrics**
```dart
// Send a custom metric
await webBridge.sendCustomMetric(
  'user_action', 
  'button_click', 
  1,
  metadata: {'screen': 'visitor_details', 'button': 'approve'}
);

// Send a custom log
await webBridge.sendCustomLog(
  'info', 
  'User approved visitor',
  source: 'visitor_management',
  metadata: {'visitor_id': '12345', 'gate_id': 'gate_001'}
);
```

## 🔍 **Verification Steps**

### **1. Check API Connection**
```bash
# Test API endpoints
curl http://localhost:8866/api/status
curl http://localhost:8866/api/dashboard
curl http://localhost:8866/api/metrics
curl http://localhost:8866/api/logs
```

### **2. Verify Flutter Integration**
```dart
// Check bridge status in your Flutter app
final webBridge = WebDashboardBridge();
print('Bridge initialized: ${webBridge.isInitialized}');
print('Data transmission active: ${webBridge.isTransmitting}');
print('API URL: ${webBridge.apiUrl}');

// Test API connection
final isConnected = await webBridge.checkApiConnection();
print('API reachable: $isConnected');
```

### **3. Monitor Web Dashboard**
1. Open http://localhost:9999
2. Check the connection indicator at the top
3. Watch for real-time updates every 5 seconds
4. Use browser console to debug: `checkApiStatus()` or `manualRefresh()`

## 🛠️ **Troubleshooting**

### **Problem: Red "API Disconnected" indicator**

**Solutions:**
1. **Check API Server**: Ensure `python3 web/realtime_api_server.py` is running
2. **Verify Port**: API should be on port 8866, web dashboard on port 9999
3. **Check Network**: Ensure localhost connectivity
4. **Browser Console**: Open DevTools and check for CORS or network errors

### **Problem: No data updates in dashboard**

**Solutions:**
1. **Initialize Bridge**: Ensure `WebDashboardBridge().initialize()` is called in Flutter
2. **Check Flutter Logs**: Look for "Data transmission to web dashboard active" messages
3. **Verify Services**: Ensure Observatory services are initialized in Flutter app
4. **Manual Test**: Use `manualRefresh()` in browser console

### **Problem: Simulated data instead of real data**

**Solutions:**
1. **Check Connection**: Verify green connection indicator
2. **Flutter Integration**: Ensure WebDashboardBridge is properly initialized
3. **API Logs**: Check API server terminal for incoming requests
4. **Network Issues**: Verify no firewall blocking localhost:8866

### **Problem: Old/stale data**

**Solutions:**
1. **Refresh Browser**: Hard refresh the web dashboard (Cmd+Shift+R)
2. **Restart API**: Stop and restart the API server
3. **Clear Cache**: Clear browser cache and reload
4. **Check Timestamps**: Verify "Last Update" shows recent time

## 📈 **Customizing Metrics Display**

### **Update Frequency**
Change the update interval in the web dashboard:
```javascript
// In browser console
setInterval(fetchDashboardData, 3000); // Update every 3 seconds
```

### **Add Custom Metrics**
1. **In Flutter**: Send custom metrics using `WebDashboardBridge.sendCustomMetric()`
2. **In API**: Metrics are automatically stored and served
3. **In Dashboard**: Modify `updateDashboardWithRealData()` to display new metrics

### **Custom Log Filtering**
Filter logs by level or source:
```javascript
// In browser console
function filterLogs(level) {
  const logs = document.querySelectorAll('.log-entry');
  logs.forEach(log => {
    const logLevel = log.querySelector('.log-level').textContent.toLowerCase();
    log.style.display = logLevel.includes(level) ? 'block' : 'none';
  });
}

filterLogs('error'); // Show only error logs
```

## 🔄 **Real-time Data Flow**

```
OneGate Flutter App
    ↓ (Every 5 seconds)
WebDashboardBridge
    ↓ (HTTP POST)
Real-time API Server (localhost:8866)
    ↓ (SQLite Storage)
Dashboard API Endpoints
    ↓ (HTTP GET every 5 seconds)
Web Dashboard (localhost:9999)
    ↓ (Live Updates)
Your Browser
```

## 🎉 **Success Indicators**

### **✅ Everything Working Correctly:**
- 🟢 Green "Connected to Real-time API" indicator
- 📊 Metrics updating every 5 seconds with real values
- 📝 Recent logs from your Flutter app appearing
- 🔄 "Last Update: Just now" timestamp
- 📈 Network requests incrementing as you use the app
- 🐛 Crash/error counts reflecting actual app state

### **❌ Issues to Fix:**
- 🔴 Red "API Disconnected" indicator
- 📊 Static/simulated data not changing
- 📝 No recent logs or generic log messages
- 🔄 "Last Update: Simulated data" message
- 📈 Unrealistic metric values (e.g., exactly 1,247 requests)

## 🚀 **Next Steps**

1. **Production Deployment**: Deploy API server to your production environment
2. **Custom Dashboards**: Create additional dashboard views for specific metrics
3. **Alerting**: Add real-time alerts for critical metrics
4. **Historical Data**: Implement data retention and historical trend analysis
5. **Mobile Integration**: Add dashboard access directly in the OneGate app

---

**Your OneGate app is now connected to a real-time web dashboard! 🎊**

**Dashboard URL**: http://localhost:9999  
**API Server**: http://localhost:8866  
**Status**: ✅ Live and monitoring your app in real-time!
