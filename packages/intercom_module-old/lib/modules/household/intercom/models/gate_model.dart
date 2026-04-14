/// Simple Gate Model matching the new API response structure
/// Used for Gatekeepers & Lobbies tab integration
/// Note: Named SimpleGateModel to avoid conflict with core/models/gate_models.dart
class SimpleGateModel {
  final int id;
  final String name;
  final String type;
  final String tag;
  final int status;
  final int? gateUserId;

  SimpleGateModel({
    required this.id,
    required this.name,
    required this.type,
    required this.tag,
    required this.status,
    this.gateUserId,
  });

  factory SimpleGateModel.fromJson(Map<String, dynamic> json) {
    return SimpleGateModel(
      id: json['id'] as int,
      name: json['gate_name'] as String,
      type: json['gate_type'] as String,
      tag: json['tag'] as String,
      status: json['status'] as int,
      gateUserId: json['gate_user_id'] as int?,
    );
  }

  /// Check if gate is active
  bool get isActive => status == 1;

  /// Check if this is a gatekeeper gate
  bool get isGatekeeper => tag == 'gate';

  /// Check if this is a lobby
  bool get isLobby => tag == 'lobby';
}
