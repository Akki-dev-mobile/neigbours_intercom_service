/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class StaffBuildingUnits extends _i1.TableRow {
  StaffBuildingUnits({
    int? id,
    required this.staff_company_building_id,
    required this.unit_id,
  }) : super(id);

  factory StaffBuildingUnits.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return StaffBuildingUnits(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      staff_company_building_id: serializationManager
          .deserialize<int>(jsonSerialization['staff_company_building_id']),
      unit_id:
          serializationManager.deserialize<int>(jsonSerialization['unit_id']),
    );
  }

  static final t = StaffBuildingUnitsTable();

  int staff_company_building_id;

  int unit_id;

  @override
  String get tableName => 'staff_building_units';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staff_company_building_id': staff_company_building_id,
      'unit_id': unit_id,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'staff_company_building_id': staff_company_building_id,
      'unit_id': unit_id,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'staff_company_building_id': staff_company_building_id,
      'unit_id': unit_id,
    };
  }

  @override
  void setColumn(
    String columnName,
    value,
  ) {
    switch (columnName) {
      case 'id':
        id = value;
        return;
      case 'staff_company_building_id':
        staff_company_building_id = value;
        return;
      case 'unit_id':
        unit_id = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  static Future<List<StaffBuildingUnits>> find(
    _i1.Session session, {
    StaffBuildingUnitsExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<StaffBuildingUnits>(
      where: where != null ? where(StaffBuildingUnits.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<StaffBuildingUnits?> findSingleRow(
    _i1.Session session, {
    StaffBuildingUnitsExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<StaffBuildingUnits>(
      where: where != null ? where(StaffBuildingUnits.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<StaffBuildingUnits?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<StaffBuildingUnits>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required StaffBuildingUnitsExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<StaffBuildingUnits>(
      where: where(StaffBuildingUnits.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    StaffBuildingUnits row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    StaffBuildingUnits row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    StaffBuildingUnits row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    StaffBuildingUnitsExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<StaffBuildingUnits>(
      where: where != null ? where(StaffBuildingUnits.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef StaffBuildingUnitsExpressionBuilder = _i1.Expression Function(
    StaffBuildingUnitsTable);

class StaffBuildingUnitsTable extends _i1.Table {
  StaffBuildingUnitsTable() : super(tableName: 'staff_building_units');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final staff_company_building_id = _i1.ColumnInt('staff_company_building_id');

  final unit_id = _i1.ColumnInt('unit_id');

  @override
  List<_i1.Column> get columns => [
        id,
        staff_company_building_id,
        unit_id,
      ];
}

@Deprecated('Use StaffBuildingUnitsTable.t instead.')
StaffBuildingUnitsTable tStaffBuildingUnits = StaffBuildingUnitsTable();
