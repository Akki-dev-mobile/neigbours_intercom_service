# PostHog Error Tracking Setup for OneGate Flutter

## 🎯 **Dashboard Access**
- **URL**: https://us.i.posthog.com
- **API Key**: `phc_g5SNI7g6Fv7WQBb8aLHnQGQKneECWNxRUup1pfxQ3mG`
- **Host**: `https://us.i.posthog.com`

## 📊 **Error Tracking Insights to Create**

### 1. **Error Rate Over Time**
- **Type**: Trends
- **Event**: `error_occurred`
- **Breakdown**: `error_type`
- **Time Range**: Last 7 days
- **Chart Type**: Line chart

### 2. **Error Types Distribution**
- **Type**: Trends
- **Event**: `error_occurred`
- **Breakdown**: `error_type`
- **Chart Type**: Pie chart

### 3. **Fatal vs Non-Fatal Errors**
- **Type**: Trends
- **Event**: `error_occurred`
- **Breakdown**: `is_fatal`
- **Chart Type**: Bar chart

### 4. **Errors by Screen**
- **Type**: Trends
- **Event**: `error_occurred`
- **Breakdown**: `screen`
- **Filter**: Where `screen` is set

### 5. **Network Errors Analysis**
- **Type**: Trends
- **Event**: `error_occurred`
- **Filter**: Where `error_type` = "NetworkException"
- **Breakdown**: `status_code`

## 🔍 **Error Event Properties**

### **Standard Properties**
```json
{
  "error_type": "string",           // Type of error (e.g., "NetworkException")
  "error_message": "string",        // Human-readable error message
  "error_context": "string",        // Context where error occurred
  "stack_trace": "string",          // Technical stack trace
  "is_fatal": "boolean",            // Whether error is fatal
  "timestamp": "ISO8601",           // When error occurred
  "platform": "flutter",           // Always "flutter" for this app
  "app_version": "string"           // App version
}
```

### **Optional Properties**
```json
{
  "screen": "string",               // Screen where error occurred
  "user_id": "string",              // User who experienced error
  "url": "string",                  // API URL for network errors
  "status_code": "number",          // HTTP status code for network errors
  "action": "string",               // User action that triggered error
  "device_info": "string"           // Device information
}
```

## 🚨 **Setting Up Error Alerts**

### 1. **High Error Rate Alert**
- **Condition**: When `error_occurred` events > 10 in 5 minutes
- **Action**: Send email/Slack notification

### 2. **Fatal Error Alert**
- **Condition**: When `error_occurred` with `is_fatal` = true
- **Action**: Immediate notification

### 3. **Network Error Spike**
- **Condition**: When `error_occurred` with `error_type` = "NetworkException" > 5 in 1 minute
- **Action**: Send notification

## 📈 **Creating a Dashboard**

### **Error Tracking Dashboard Layout**
1. **Top Row**: Error rate trends, total errors today
2. **Middle Row**: Error types breakdown, fatal vs non-fatal
3. **Bottom Row**: Errors by screen, recent error events table

### **Dashboard Filters**
- Time range selector
- Error type filter
- Fatal/non-fatal toggle
- User ID filter
- Screen filter

## 🔧 **Troubleshooting Missing Errors**

### **Check Configuration**
1. Verify API key in `.env` file
2. Confirm PostHog initialization in app
3. Check network connectivity
4. Verify error tracking code is called

### **Debug Steps**
1. Check browser network tab for PostHog requests
2. Look for PostHog initialization logs
3. Verify error events are being sent
4. Check PostHog project settings

### **Common Issues**
- **No events showing**: Check API key and host configuration
- **Events delayed**: PostHog has ~1-2 minute delay for real-time data
- **Missing properties**: Verify error tracking implementation
- **Duplicate events**: Check for multiple PostHog initializations

## 🧪 **Testing Error Tracking**

### **Manual Testing**
1. Use the error tracking test widget: `/error-tracking-test` route
2. Trigger errors in the app and verify they appear in PostHog
3. Check that all expected properties are included

### **Automated Testing**
```bash
# Send test error via curl
curl -X POST https://us.i.posthog.com/capture/ \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": "phc_g5SNI7g6Fv7WQBb8aLHnQGQKneECWNxRUup1pfxQ3mG",
    "event": "error_occurred",
    "properties": {
      "error_type": "TestException",
      "error_message": "Test error message",
      "error_context": "test",
      "is_fatal": false,
      "platform": "flutter"
    },
    "distinct_id": "test_user"
  }'
```

## 📋 **Error Analysis Workflow**

### **Daily Error Review**
1. Check error rate trends
2. Identify new error types
3. Review fatal errors
4. Analyze error patterns by screen/user

### **Weekly Error Analysis**
1. Compare error rates week-over-week
2. Identify recurring issues
3. Plan fixes for high-impact errors
4. Update error handling based on patterns

### **Error Response Process**
1. **Fatal Errors**: Immediate investigation
2. **High-frequency Errors**: Priority fix in next release
3. **Network Errors**: Check API status and connectivity
4. **User-specific Errors**: Investigate user journey

## 🔗 **Useful PostHog URLs**

- **Events**: https://us.i.posthog.com/events
- **Insights**: https://us.i.posthog.com/insights
- **Dashboards**: https://us.i.posthog.com/dashboard
- **Project Settings**: https://us.i.posthog.com/project/settings
