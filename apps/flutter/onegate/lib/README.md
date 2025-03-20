# OneGate Error Handling

This document describes the comprehensive error handling implementation in the OneGate application, with a focus on the `RemoteDataSource` class.

## Error Handling Approach

The application implements error handling in API calls through two main strategies:

1. **Internal Helper Method**: Using `_handleResponse` in `RemoteDataSource` class
2. **External Utility Class**: Using `ApiErrorHandler` utility 
3. **Universal API Call Method**: Using `makeApiCall` for simplified future implementations

## Internal Helper Method

The `_handleResponse` method provides a standardized way to handle API responses and show error screens for non-200 status codes:

```dart
Future<dynamic> _handleResponse(Future<Response> apiCall, BuildContext? context) async {
  try {
    final response = await apiCall;
    if (response.statusCode == 200) {
      return response.data;
    } else {
      log('Non-200 status code: ${response.statusCode}');
      
      // Show error screen if context is provided
      if (context != null) {
        _showErrorScreen(
          context, 
          'Error ${response.statusCode}: ${response.statusMessage ?? "Something went wrong"}',
        );
      }
      
      // Still return the response to allow the caller to handle it if needed
      return response.data;
    }
  } on DioError catch (e) {
    // Handle Dio errors
    // ...
  } catch (e) {
    // Handle other errors
    // ...
  }
}
```

## External Utility Class

The `ApiErrorHandler` utility class provides a more flexible, reusable approach to handling API errors throughout the app:

```dart
static Future<T?> handleResponse<T>({
  required Future<Response> apiCall,
  BuildContext? context,
  required T Function(dynamic data) onSuccess,
  Function(dynamic error)? onError,
}) async {
  // Implementation...
}
```

## Universal API Call Method

The `makeApiCall` method provides a simplified interface for making API calls with built-in error handling:

```dart
Future<dynamic> makeApiCall({
  required String url,
  required String method,
  Map<String, dynamic>? queryParams,
  dynamic data,
  Map<String, String>? headers,
  BuildContext? context,
  String errorMessage = "An error occurred",
}) async {
  // Implementation...
}
```

## Usage Examples

### Using Internal Helper Method

```dart
Future<List<dynamic>> fetchGates({BuildContext? context}) async {
  // ...
  final apiCall = Dio().get(ApiUrls.gates, /* ... */);
  final responseData = await _handleResponse(apiCall, context);
  // ...
}
```

### Using ApiErrorHandler Utility

```dart
Future<List<dynamic>> fetchSocieties(String userId, {BuildContext? context}) async {
  final apiCall = Dio().get(/* ... */);
  
  return await ApiErrorHandler.handleResponse<List<dynamic>>(
    apiCall: apiCall,
    context: context,
    onSuccess: (data) {
      // Handle successful response
    },
    onError: (error) {
      // Handle error
    },
  ) ?? [];
}
```

### Using Universal API Call Method

```dart
Future<Map<String, dynamic>> fetchUserProfile(String userId, {BuildContext? context}) async {
  try {
    final url = '${ApiUrls.gateBaseUrl}/users/$userId/profile';
    
    final responseData = await makeApiCall(
      url: url,
      method: 'GET',
      context: context,
      errorMessage: "Failed to fetch user profile",
    );
    
    // Process response data
  } catch (e) {
    // Handle errors
  }
}
```

## Benefits

1. **Consistency**: Standardized error handling across all API calls
2. **User Experience**: Proper error screens shown to users when API errors occur
3. **Maintainability**: Simplified error handling code that's easier to maintain
4. **Flexibility**: Multiple approaches depending on the use case
5. **Context-Aware**: Error handling that adapts based on whether a BuildContext is available 