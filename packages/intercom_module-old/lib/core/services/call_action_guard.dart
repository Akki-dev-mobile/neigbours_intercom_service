/// Prevents duplicate CallKit accept actions for the same call id.
class CallActionGuard {
  CallActionGuard._();

  static final CallActionGuard instance = CallActionGuard._();

  final Set<String> _acceptInFlight = <String>{};

  bool isAcceptInFlight(String callId) {
    final normalized = callId.trim();
    if (normalized.isEmpty) return false;
    return _acceptInFlight.contains(normalized);
  }

  bool tryBeginAccept(String callId) {
    final normalized = callId.trim();
    if (normalized.isEmpty) return false;
    if (_acceptInFlight.contains(normalized)) return false;
    _acceptInFlight.add(normalized);
    return true;
  }

  void clearCall(String callId) {
    final normalized = callId.trim();
    if (normalized.isEmpty) return;
    _acceptInFlight.remove(normalized);
  }
}
