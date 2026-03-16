# Why the app might log out

The app can navigate to the login screen (or show "session expired") in these cases:

1. **Token expired and refresh failed**  
   Access token expired and refresh token was invalid or the refresh request failed (network, 401 from auth server). The session listener in `main.dart` and `SessionManagementCoordinator` handle this and can show the session-expired modal or navigate to login.

2. **401 Unauthorized after retries**  
   An API call returned 401 and the auth interceptor retried after refreshing the token. If refresh or retry failed, the app may log out or show an error. See `secure_auth_interceptor.dart` and `enhanced_auth_interceptor.dart`.

3. **User tapped Logout**  
   Explicit logout from Settings or elsewhere calls `CentralizedLogoutService` / `AuthService.logout()` and clears tokens, then navigates to login.

4. **Session state = unauthenticated**  
   `UserSessionManager` emitted `UserSessionState.unauthenticated` (e.g. after detecting invalid/expired tokens), which triggers navigation to login in `_handleSessionStateChange` in `main.dart`.

**Reducing unexpected logouts**

- Ensure token refresh runs before access token expiry (see `enhanced_token_refresh_manager.dart` and session expiry fix in `main.dart`).
- For development or kiosk use, "continuous session" flags can reduce logouts: `token_expiration_logout_disabled`, `auto_logout_disabled`, `continuous_session_active` in SharedPreferences (see `_shouldShowSessionExpiredModal` in `main.dart`).
- When navigating to the login screen, `SessionManagementCoordinator.setNavigatingToLogin(true)` is set so the session-expired modal is not shown on top of login.
