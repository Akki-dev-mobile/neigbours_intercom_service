# Token Notification Configuration

## Overview

The OneGate app now supports configuring whether token refresh snackbar notifications are displayed to users. By default, these notifications are **disabled** to provide a cleaner user experience.

## What Was Changed

### 1. TokenNotificationService Configuration

The `TokenNotificationService` now includes configuration options to control notification display:

```dart
// Configure whether to show notifications
tokenNotificationService.setShowNotifications(false); // Disable notifications
tokenNotificationService.setShowNotifications(true);  // Enable notifications

// Check current configuration
bool isEnabled = tokenNotificationService.showNotifications;
```

### 2. Hidden Notifications

When notifications are disabled (`_showNotifications = false`), the following snackbars will not be shown:

- **Token Refresh Progress**: "🔄 Refreshing token, please wait..."
- **Token Refresh Success**: "✅ Token refreshed successfully! 👤 Welcome back, [User]"
- **Token Refresh Failure**: "❌ Token refresh failed. Please login again."
- **Authentication Error**: "🚫 Authentication failed. Please login again."

### 3. Logging Preserved

Even when notifications are disabled, all logging functionality is preserved:

```
🔄 Token refresh progress notification logged only
✅ Token refresh success notification logged only
❌ Token refresh failure notification logged only
🚫 Authentication error notification logged only
```

## Configuration

### Default Configuration

By default, token refresh notifications are **disabled** in the main.dart file:

```dart
// Configure TokenNotificationService to hide snackbar notifications
final tokenNotificationService = TokenNotificationService();
tokenNotificationService.setShowNotifications(false);
log('🔧 Token refresh snackbar notifications disabled');
```

### Enabling Notifications

To enable notifications (for debugging or testing), you can:

1. **Temporarily enable in main.dart**:
```dart
tokenNotificationService.setShowNotifications(true);
```

2. **Enable programmatically**:
```dart
final service = TokenNotificationService();
service.setShowNotifications(true);
```

## Benefits

### 1. Cleaner User Experience
- No interrupting snackbars during token refresh
- Seamless background authentication
- Reduced UI clutter

### 2. Preserved Functionality
- All token refresh logic remains unchanged
- Logging and debugging information preserved
- Error handling still functional

### 3. Configurable
- Easy to enable for debugging
- Can be controlled per environment
- Maintains backward compatibility

## Testing

The configuration functionality is fully tested:

```bash
flutter test test/services/auth_service/token_notification_service_test.dart --plain-name "Notification Configuration"
```

Test coverage includes:
- ✅ Enabling notifications
- ✅ Disabling notifications  
- ✅ Default state (disabled)
- ✅ Configuration persistence

## Implementation Details

### Modified Files

1. **`lib/services/auth_service/token_notification_service.dart`**
   - Added `_showNotifications` configuration flag
   - Added `setShowNotifications()` method
   - Added `showNotifications` getter
   - Modified notification methods to respect configuration

2. **`lib/main.dart`**
   - Added TokenNotificationService import
   - Added configuration to disable notifications by default

3. **`test/services/auth_service/token_notification_service_test.dart`**
   - Added comprehensive tests for notification configuration

### Backward Compatibility

This change is fully backward compatible:
- Existing code continues to work unchanged
- Default behavior is to hide notifications (cleaner UX)
- Can be easily enabled if needed

## Future Enhancements

Potential future improvements:
- Environment-based configuration
- User preference settings
- Granular notification control (per notification type)
- Debug mode auto-enable
