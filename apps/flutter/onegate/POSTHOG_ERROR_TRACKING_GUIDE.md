# 🐛 PostHog Error Tracking Guide for OneGate Flutter

## 📊 **Dashboard Access**

- **PostHog Dashboard**: https://us.i.posthog.com
- **Events Section**: https://us.i.posthog.com/events
- **API Key**: `phc_g5SNI7g6Fv7WQBb8aLHnQGQKneECWNxRUup1pfxQ3mG`
- **Host**: `https://us.i.posthog.com`

## 🔍 **Finding Error Events**

### **1. Navigate to Events**
1. Go to https://us.i.posthog.com/events
2. In the search bar, type: `error_occurred`
3. Set time range to "Last 24 hours" or "Last 7 days"

### **2. Error Event Properties**
Each error event contains these properties:
- `error_type`: Type of exception (e.g., NetworkException, UserActionException)
- `error_message`: Human-readable error description
- `error_context`: Where the error occurred (e.g., network_request, user_interaction)
- `stack_trace`: Full stack trace for debugging
- `is_fatal`: Whether the error caused app crash
- `timestamp`: When the error occurred
- `platform`: Always "flutter" for our app
- `app_version`: Version of the OneGate app
- `user_id`: ID of the user who experienced the error (if available)
- `screen`: Screen where error occurred (if available)

## 📈 **Error Analysis Features**

### **1. Error Trends**
- **Insights Tab**: Create charts showing error frequency over time
- **Filter by error_type**: See which types of errors are most common
- **Group by properties**: Analyze errors by screen, user, or context

### **2. Error Filtering**
```
Event: error_occurred
Properties:
- error_type = "NetworkException"  // Network-related errors
- error_type = "UserActionException"  // User interaction errors
- is_fatal = true  // Only fatal errors
- screen = "visitor_dashboard"  // Errors on specific screen
```

### **3. Create Error Dashboards**
1. Go to "Insights" → "New Insight"
2. Select "Trends"
3. Event: `error_occurred`
4. Group by: `error_type` or `error_context`
5. Save to dashboard

## 🚨 **Error Monitoring Setup**

### **1. Create Error Alerts**
1. Go to "Alerts" in PostHog
2. Create new alert for `error_occurred` events
3. Set threshold (e.g., > 10 errors in 1 hour)
4. Configure notification channels

### **2. Error Rate Monitoring**
Create insights to track:
- Total errors per day
- Error rate by user
- Most common error types
- Fatal vs non-fatal errors

## 🔧 **Troubleshooting Missing Errors**

### **1. Check Configuration**
Verify in your Flutter app:
```dart
// In .env file
POSTHOG_API_KEY=phc_g5SNI7g6Fv7WQBb8aLHnQGQKneECWNxRUup1pfxQ3mG
POSTHOG_HOST=https://us.i.posthog.com

// In comprehensive_monitoring_service.dart
await Posthog().capture(
  eventName: 'error_occurred',
  properties: {
    'error_type': error.runtimeType.toString(),
    'error_message': error.toString(),
    // ... other properties
  },
);
```

### **2. Test Error Tracking**
Run test errors using curl:
```bash
curl -X POST https://us.i.posthog.com/capture/ \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": "phc_g5SNI7g6Fv7WQBb8aLHnQGQKneECWNxRUup1pfxQ3mG",
    "event": "error_occurred",
    "properties": {
      "error_type": "TestException",
      "error_message": "Test error message",
      "test_type": "manual_verification"
    },
    "distinct_id": "test_user"
  }'
```

### **3. Debug Checklist**
- [ ] PostHog initialized in app startup
- [ ] API key and host configured correctly
- [ ] Error tracking code added to comprehensive monitoring service
- [ ] Network connectivity available
- [ ] No firewall blocking PostHog requests

## 📋 **Error Event Examples**

### **Network Error**
```json
{
  "event": "error_occurred",
  "properties": {
    "error_type": "NetworkException",
    "error_message": "Connection timeout",
    "error_context": "api_request",
    "url": "https://api.onegate.com/visitors",
    "status_code": 408,
    "is_fatal": false
  }
}
```

### **User Action Error**
```json
{
  "event": "error_occurred",
  "properties": {
    "error_type": "UserActionException",
    "error_message": "Invalid visitor approval",
    "error_context": "user_interaction",
    "screen": "visitor_dashboard",
    "action": "approve_visitor",
    "user_id": "gatekeeper_123",
    "is_fatal": false
  }
}
```

### **Fatal Error**
```json
{
  "event": "error_occurred",
  "properties": {
    "error_type": "FatalException",
    "error_message": "Unhandled exception",
    "error_context": "application_crash",
    "stack_trace": "Full stack trace...",
    "is_fatal": true
  }
}
```

## 🎯 **Best Practices**

### **1. Error Categorization**
- Use consistent `error_type` values
- Include meaningful `error_context`
- Add relevant metadata (screen, user_id, etc.)

### **2. Error Monitoring**
- Set up alerts for critical errors
- Monitor error trends weekly
- Track error resolution progress

### **3. Error Response**
- Investigate high-frequency errors first
- Use stack traces for debugging
- Track error fixes with app versions

## 🔗 **Quick Links**

- **Events**: https://us.i.posthog.com/events?search=error_occurred
- **Insights**: https://us.i.posthog.com/insights
- **Dashboards**: https://us.i.posthog.com/dashboard
- **Alerts**: https://us.i.posthog.com/alerts

## 📞 **Support**

If you need help with PostHog error tracking:
1. Check the PostHog documentation
2. Verify configuration in the Flutter app
3. Test with manual curl commands
4. Review network connectivity and firewall settings
