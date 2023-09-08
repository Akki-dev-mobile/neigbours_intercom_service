import 'package:flutter_onegate/domain/entities/gate/gate.dart';
import 'package:flutter_onegate/domain/entities/gate/gate_list_response.dart';

class GateListResponseMapper {
  static GateListResponse fromJson(Map<String, dynamic> json) {
    final List<dynamic> gateList = json['gates'];
    final gates = gateList.map((gateJson) => Gate.fromJson(gateJson)).toList();

    return GateListResponse(gates: gates);
  }

  static Map<String, dynamic> toJson(GateListResponse response) {
    return {
      'gates': response.gates.map((gate) => gate.toJson()).toList(),
    };
  }
}
