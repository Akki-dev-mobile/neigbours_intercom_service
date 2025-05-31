# OneGate Refresh Token Failure Handling System

## Overview

This document describes the comprehensive refresh token failure handling system implemented in the OneGate Flutter app. The system provides robust error handling, automatic recovery mechanisms, and seamless integration with the continuous session management system.

## Architecture

### Core Components

1. **RefreshTokenErrorHandler** - Central error analysis and handling service
2. **EnhancedTokenRefreshManager** - Enhanced token manager with failure handling
3. **DynamicTokenRefreshManager** - Dynamic refresh timing with error integration
4. **ContinuousSessionManager** - Session management with failure awareness

### Error Classification

The system classifies refresh token failures into specific types:

#### Network-Related Failures
- `networkTimeout` - Connection timeout during refresh
- `networkUnavailable` - No internet connection
- `connectionError` - General connection issues

#### Authentication Failures
- `refreshTokenExpired` - Refresh token has expired
- `refreshTokenRevoked` - Refresh token revoked by server
- `refreshTokenInvalid` - Malformed or corrupted refresh token
- `missingRefreshToken` - No refresh token available

#### Server-Side Failures
- `serverError` - HTTP 5xx responses
- `serviceUnavailable` - Service temporarily down
- `invalidResponse` - Unexpected response format

#### Client-Side Failures
- `storageError` - Secure storage access issues
- `configurationError` - App configuration problems

## Failure Handling Flow

### 1. Error Detection and Analysis

```dart
// Automatic error analysis
final failureType = RefreshTokenErrorHandler.analyzeFailure(error);
```

The system automatically analyzes exceptions and HTTP responses to determine the specific failure type.

### 2. Resolution Strategy Determination

Based on the failure type and attempt number, the system determines the appropriate resolution:

- **Retry Immediate** - For transient storage errors
- **Retry with Backoff** - For network and server errors
- **Show User Error** - For recoverable issues requiring user action
- **Force Reauth** - For authentication failures
- **Deactivate Session** - For permanent failures

### 3. Exponential Backoff

The system implements exponential backoff for retry attempts:

```dart
Duration delay = baseDelay * (2^(attemptNumber - 1))
```

With a maximum delay cap to prevent excessive waiting.

### 4. Continuous Session Integration

When authentication failures occur, the system:

1. Deactivates the continuous session
2. Shows the session expired modal
3. Clears all tokens
4. Navigates to login screen

## Usage Examples

### Basic Error Handling

```dart
try {
  final refreshed = await tokenManager.refreshTokenIfNeeded();
  if (!refreshed) {
    // Error handling is automatic
  }
} catch (e) {
  // Comprehensive error analysis and handling
  await RefreshTokenErrorHandler.handleRefreshTokenFailure(
    e,
    attemptNumber,
    null, // Auto-detect failure type
  );
}
```

### Manual Failure Analysis

```dart
final failureType = RefreshTokenErrorHandler.analyzeFailure(error);
final shouldRetry = RefreshTokenErrorHandler.shouldRetryFailure(failureType);
final delay = RefreshTokenErrorHandler.calculateBackoffDelay(attemptNumber);
```

### Failure Statistics

```dart
final stats = tokenManager.getRefreshFailureStatistics();
print('Consecutive failures: ${stats['consecutiveFailures']}');
print('Last failure: ${stats['lastFailureTime']}');
```

## Configuration

### Retry Limits

- Maximum retry attempts: 3
- Maximum consecutive failures before force reauth: 5
- Base retry delay: 2 seconds
- Maximum retry delay: 30 seconds

### Failure Thresholds

The system tracks consecutive failures and forces reauthentication after 5 consecutive failures to prevent infinite retry loops.

## User Experience

### Error Messages

The system provides user-friendly error messages based on failure types:

- Network issues: "Connection timed out. Please check your internet connection."
- Server issues: "Server is temporarily unavailable. Please try again later."
- Authentication issues: "Your session has expired. Please log in again."

### Session Expiration Modal

For authentication failures, the system shows an animated modal bottom sheet with:

- Clear explanation of the issue
- Login Again button
- Automatic token cleanup
- Navigation to login screen

## Testing

The system includes comprehensive tests in `DynamicTokenRefreshTestSuite`:

### Test Categories

1. **Failure Analysis Tests** - Verify correct error classification
2. **Retry Logic Tests** - Validate retry decisions and backoff calculations
3. **Recovery Mechanism Tests** - Test failure counter reset and recovery
4. **Integration Tests** - Verify continuous session integration

### Running Tests

```dart
final testSuite = DynamicTokenRefreshTestSuite();
final results = await testSuite.runCompleteTestSuite();
```

## Best Practices

### For Developers

1. Always use the enhanced token manager for token operations
2. Let the system handle failures automatically
3. Monitor failure statistics for debugging
4. Test with various network conditions

### For Error Handling

1. Classify errors correctly for appropriate handling
2. Provide clear user feedback for non-retryable errors
3. Implement graceful degradation for service unavailability
4. Maintain session continuity where possible

## Troubleshooting

### Common Issues

1. **Excessive Retries** - Check failure classification logic
2. **Session Not Deactivating** - Verify continuous session integration
3. **User Not Redirected** - Check navigation context availability
4. **Storage Errors** - Verify secure storage permissions

### Debug Information

Enable detailed logging to see:
- Failure analysis results
- Retry attempt details
- Resolution strategy execution
- Session state changes

## Future Enhancements

1. **Adaptive Retry Timing** - Adjust delays based on network conditions
2. **Failure Pattern Analysis** - Detect and respond to failure patterns
3. **Offline Mode Support** - Handle offline scenarios gracefully
4. **Enhanced Metrics** - Detailed failure analytics and reporting
