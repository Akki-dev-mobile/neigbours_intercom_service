/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class VisitorBuildingUnits extends _i1.TableRow {
  VisitorBuildingUnits({
    int? id,
    required this.visitor_company_building_id,
    required this.unit_id,
  }) : super(id);

  factory VisitorBuildingUnits.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return VisitorBuildingUnits(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      visitor_company_building_id: serializationManager
          .deserialize<int>(jsonSerialization['visitor_company_building_id']),
      unit_id:
          serializationManager.deserialize<int>(jsonSerialization['unit_id']),
    );
  }

  static final t = VisitorBuildingUnitsTable();

  int visitor_company_building_id;

  int unit_id;

  @override
  String get tableName => 'visitor_building_units';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitor_company_building_id': visitor_company_building_id,
      'unit_id': unit_id,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'visitor_company_building_id': visitor_company_building_id,
      'unit_id': unit_id,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'visitor_company_building_id': visitor_company_building_id,
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
      case 'visitor_company_building_id':
        visitor_company_building_id = value;
        return;
      case 'unit_id':
        unit_id = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  static Future<List<VisitorBuildingUnits>> find(
    _i1.Session session, {
    VisitorBuildingUnitsExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<VisitorBuildingUnits>(
      where: where != null ? where(VisitorBuildingUnits.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<VisitorBuildingUnits?> findSingleRow(
    _i1.Session session, {
    VisitorBuildingUnitsExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<VisitorBuildingUnits>(
      where: where != null ? where(VisitorBuildingUnits.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<VisitorBuildingUnits?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<VisitorBuildingUnits>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required VisitorBuildingUnitsExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<VisitorBuildingUnits>(
      where: where(VisitorBuildingUnits.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    VisitorBuildingUnits row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    VisitorBuildingUnits row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    VisitorBuildingUnits row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    VisitorBuildingUnitsExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<VisitorBuildingUnits>(
      where: where != null ? where(VisitorBuildingUnits.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef VisitorBuildingUnitsExpressionBuilder = _i1.Expression Function(
    VisitorBuildingUnitsTable);

class VisitorBuildingUnitsTable extends _i1.Table {
  VisitorBuildingUnitsTable() : super(tableName: 'visitor_building_units');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final visitor_company_building_id =
      _i1.ColumnInt('visitor_company_building_id');

  final unit_id = _i1.ColumnInt('unit_id');

  @override
  List<_i1.Column> get columns => [
        id,
        visitor_company_building_id,
        unit_id,
      ];
}

@Deprecated('Use VisitorBuildingUnitsTable.t instead.')
VisitorBuildingUnitsTable tVisitorBuildingUnits = VisitorBuildingUnitsTable();
