import 'package:flutter_onegate/domain/entities/gate/gate.dart';
import 'package:flutter_onegate/domain/entities/gate/gate_list_response.dart';
import 'package:flutter_onegate/domain/mappers/gate/gate_mapper.dart';

class GateListResponseMapper {
  static GateListResponse fromJson(Map<String, dynamic> json) {
    final List<dynamic> gateList = json['data'];
    final gates = gateList.map((gateJson) => Gate.fromJson(gateJson)).toList();

    return GateListResponse(gates: gates);
  }

  static Map<String, dynamic> toJson(GateListResponse response) {
    return {
      'data': response.gates.map((gate) => GateMapper.toJson(gate)).toList(),
    };
  }
}