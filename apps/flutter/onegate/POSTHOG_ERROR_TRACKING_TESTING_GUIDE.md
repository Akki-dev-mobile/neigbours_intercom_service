# PostHog Error Tracking Testing Guide for OneGate Flutter

## 🎯 **Overview**
This guide provides comprehensive instructions for testing the PostHog Error Tracking implementation in the OneGate Flutter application.

## 📊 **PostHog Error Tracking Dashboard**
- **URL**: https://us.posthog.com/project/170509/error_tracking
- **API Key**: `phc_g5SNI7g6Fv7WQBb8aLHnQGQKneECWNxRUup1pfxQ3mG`
- **Host**: `https://us.i.posthog.com`

## 🧪 **Testing Methods**

### **Method 1: Using the Error Tracking Test Widget**

1. **Access the Test Widget**:
   ```bash
   # In debug mode, navigate to the error tracking test route
   # Route: /error-tracking-test
   ```

2. **Available Test Buttons**:
   - **Test PostHog Error**: Direct PostHog error event
   - **Test All Platforms Error**: Comprehensive monitoring error
   - **Test Crash Reporter**: Crash reporter integration
   - **Test Analytics Error**: Analytics service error
   - **Test Flutter Framework Error**: Flutter framework error
   - **Test PostHog Error Tracking**: Specific PostHog error tracking tests

3. **Expected Results**:
   - Each test should show success message in the widget
   - Errors should appear in PostHog dashboard within 1-2 minutes

### **Method 2: Using the Comprehensive Test Script**

1. **Run the Test Script**:
   ```bash
   cd apps/flutter/onegate
   flutter run test_comprehensive_error_tracking.dart
   ```

2. **Test Coverage**:
   - Flutter Framework Errors
   - Network Errors
   - User Action Errors
   - Platform Errors
   - Fatal Errors
   - API Errors
   - Validation Errors
   - Authentication Errors

### **Method 3: Manual Error Triggering**

1. **Trigger Network Errors**:
   - Disconnect internet and try to sync visitors
   - Use invalid API endpoints
   - Simulate timeout scenarios

2. **Trigger User Action Errors**:
   - Try to approve already approved visitors
   - Submit invalid form data
   - Perform actions without proper permissions

3. **Trigger Platform Errors**:
   - Deny camera permissions and try QR scanning
   - Access restricted device features

## 🔍 **Verifying Error Data in PostHog**

### **Dashboard Navigation**
1. Open: https://us.posthog.com/project/170509/error_tracking
2. Look for `$exception` events
3. Filter by error types and time ranges

### **Error Properties to Verify**

#### **Standard Properties**
- `$exception_type`: Type of error (e.g., "NetworkException")
- `$exception_message`: Human-readable error message
- `$exception_stack_trace`: Technical stack trace
- `$exception_fingerprint`: Unique error identifier
- `$exception_level`: Severity (error, fatal)
- `$exception_handled`: Whether error was caught

#### **Context Properties**
- `error_context`: Where the error occurred
- `current_screen`: Screen/page name
- `timestamp`: When error occurred
- `is_fatal`: Whether error is fatal

#### **User Properties**
- `user_id`: User identifier
- `session_id`: Session identifier
- `gate_id`: Gate identifier

#### **Device Properties**
- `device_model`: Device model
- `device_os`: Operating system
- `device_os_version`: OS version
- `app_version`: App version

#### **Additional Properties**
- `url`: For network errors
- `method`: HTTP method for API errors
- `status_code`: HTTP status code
- `action`: User action that triggered error

### **Error Filtering and Analysis**

#### **Filter by Error Type**
```
$exception_type = "NetworkException"
$exception_type = "UserActionException"
$exception_type = "FlutterError"
```

#### **Filter by Severity**
```
$exception_level = "fatal"
$exception_level = "error"
```

#### **Filter by Context**
```
error_context = "network_request"
error_context = "user_interaction"
error_context = "flutter_framework"
```

#### **Filter by Screen**
```
current_screen = "dashboard"
current_screen = "visitor_list"
current_screen = "login"
```

## 📈 **Creating Error Tracking Insights**

### **1. Error Rate Trends**
- **Type**: Trends
- **Event**: `$exception`
- **Breakdown**: `$exception_type`
- **Time Range**: Last 7 days

### **2. Error Distribution by Screen**
- **Type**: Trends
- **Event**: `$exception`
- **Breakdown**: `current_screen`
- **Chart Type**: Pie chart

### **3. Fatal vs Non-Fatal Errors**
- **Type**: Trends
- **Event**: `$exception`
- **Breakdown**: `$exception_level`
- **Chart Type**: Bar chart

### **4. Network Error Analysis**
- **Type**: Trends
- **Event**: `$exception`
- **Filter**: `$exception_type = "NetworkException"`
- **Breakdown**: `status_code`

### **5. User Action Errors by Action Type**
- **Type**: Trends
- **Event**: `$exception`
- **Filter**: `$exception_type = "UserActionException"`
- **Breakdown**: `action`

## 🚨 **Setting Up Error Alerts**

### **1. High Error Rate Alert**
```
Condition: $exception events > 10 in 5 minutes
Action: Send email/Slack notification
```

### **2. Fatal Error Alert**
```
Condition: $exception with $exception_level = "fatal"
Action: Immediate notification
```

### **3. Network Error Spike**
```
Condition: $exception with $exception_type = "NetworkException" > 5 in 1 minute
Action: Send notification
```

## 🔧 **Troubleshooting**

### **No Errors Appearing in PostHog**

1. **Check API Key Configuration**:
   ```bash
   # Verify .env file
   cat apps/flutter/onegate/.env
   ```

2. **Check PostHog Initialization**:
   - Look for initialization logs in app console
   - Verify PostHog service is initialized before errors occur

3. **Check Network Connectivity**:
   - Ensure app can reach `https://us.i.posthog.com`
   - Check for network restrictions or firewalls

4. **Check Error Tracking Service**:
   - Verify `PostHogErrorTrackingService` is initialized
   - Check for error tracking service logs

### **Errors Not Categorized Properly**

1. **Check Error Properties**:
   - Verify all required properties are included
   - Check property naming conventions

2. **Check Error Fingerprinting**:
   - Ensure unique fingerprints for different error types
   - Verify fingerprint generation logic

### **Missing Context Information**

1. **Check User Context**:
   - Verify user ID, session ID, and gate ID are set
   - Check context loading from storage

2. **Check Screen Tracking**:
   - Verify current screen is being tracked
   - Check screen name updates

## 📊 **Expected Test Results**

### **Successful Implementation Should Show**:
- ✅ Multiple `$exception` events in PostHog dashboard
- ✅ Proper error categorization by type
- ✅ Complete context information for each error
- ✅ Correct user and session tracking
- ✅ Proper error fingerprinting for deduplication
- ✅ Real-time error reporting (1-2 minute delay)

### **Error Properties Verification Checklist**:
- [ ] `$exception_type` is correctly set
- [ ] `$exception_message` is descriptive
- [ ] `$exception_stack_trace` is included
- [ ] `$exception_level` matches error severity
- [ ] `error_context` provides useful information
- [ ] `current_screen` is accurate
- [ ] `user_id` and `session_id` are present
- [ ] Device information is complete
- [ ] App version is correct

## 🎯 **Next Steps After Testing**

1. **Monitor Real Usage**:
   - Deploy app and monitor real error patterns
   - Analyze error trends and frequencies

2. **Set Up Dashboards**:
   - Create error monitoring dashboards
   - Set up automated alerts

3. **Improve Error Handling**:
   - Use error data to improve app stability
   - Implement better error recovery mechanisms

4. **Regular Review**:
   - Weekly error analysis
   - Monthly error trend review
   - Quarterly error handling improvements
