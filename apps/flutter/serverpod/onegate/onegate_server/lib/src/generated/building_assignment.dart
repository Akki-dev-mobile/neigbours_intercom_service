/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class BuildingAssignment extends _i1.TableRow {
  BuildingAssignment({
    int? id,
    this.visitor_id,
    required this.company_id,
    required this.building_id,
    required this.unit_id,
  }) : super(id);

  factory BuildingAssignment.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return BuildingAssignment(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      visitor_id: serializationManager
          .deserialize<int?>(jsonSerialization['visitor_id']),
      company_id: serializationManager
          .deserialize<int>(jsonSerialization['company_id']),
      building_id: serializationManager
          .deserialize<int>(jsonSerialization['building_id']),
      unit_id: serializationManager
          .deserialize<List<String>>(jsonSerialization['unit_id']),
    );
  }

  static final t = BuildingAssignmentTable();

  int? visitor_id;

  int company_id;

  int building_id;

  List<String> unit_id;

  @override
  String get tableName => 'building_assignment';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'company_id': company_id,
      'building_id': building_id,
      'unit_id': unit_id,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'company_id': company_id,
      'building_id': building_id,
      'unit_id': unit_id,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'company_id': company_id,
      'building_id': building_id,
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
      case 'visitor_id':
        visitor_id = value;
        return;
      case 'company_id':
        company_id = value;
        return;
      case 'building_id':
        building_id = value;
        return;
      case 'unit_id':
        unit_id = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  static Future<List<BuildingAssignment>> find(
    _i1.Session session, {
    BuildingAssignmentExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<BuildingAssignment>(
      where: where != null ? where(BuildingAssignment.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<BuildingAssignment?> findSingleRow(
    _i1.Session session, {
    BuildingAssignmentExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<BuildingAssignment>(
      where: where != null ? where(BuildingAssignment.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<BuildingAssignment?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<BuildingAssignment>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required BuildingAssignmentExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<BuildingAssignment>(
      where: where(BuildingAssignment.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    BuildingAssignment row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    BuildingAssignment row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    BuildingAssignment row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    BuildingAssignmentExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<BuildingAssignment>(
      where: where != null ? where(BuildingAssignment.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef BuildingAssignmentExpressionBuilder = _i1.Expression Function(
    BuildingAssignmentTable);

class BuildingAssignmentTable extends _i1.Table {
  BuildingAssignmentTable() : super(tableName: 'building_assignment');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final visitor_id = _i1.ColumnInt('visitor_id');

  final company_id = _i1.ColumnInt('company_id');

  final building_id = _i1.ColumnInt('building_id');

  final unit_id = _i1.ColumnSerializable('unit_id');

  @override
  List<_i1.Column> get columns => [
        id,
        visitor_id,
        company_id,
        building_id,
        unit_id,
      ];
}

@Deprecated('Use BuildingAssignmentTable.t instead.')
BuildingAssignmentTable tBuildingAssignment = BuildingAssignmentTable();
