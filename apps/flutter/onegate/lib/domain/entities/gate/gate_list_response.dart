import 'package:flutter_onegate/domain/entities/gate/gate.dart';

class GateListResponse {
  final List<Gate> gates;

  GateListResponse({required this.gates});

  factory GateListResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> gateList = json['gates'];
    final gates = gateList.map((gateJson) => Gate.fromJson(gateJson)).toList();

    return GateListResponse(gates: gates);
  }

  Map<String, dynamic> toJson() {
    return {
      'gates': gates.map((gate) => gate.toJson()).toList(),
    };
  }
}
