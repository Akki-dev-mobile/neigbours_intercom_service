/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class StaffCompanyBuilding extends _i1.TableRow {
  StaffCompanyBuilding({
    int? id,
    required this.staff_comapany_id,
    required this.building_id,
  }) : super(id);

  factory StaffCompanyBuilding.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return StaffCompanyBuilding(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      staff_comapany_id: serializationManager
          .deserialize<int>(jsonSerialization['staff_comapany_id']),
      building_id: serializationManager
          .deserialize<int>(jsonSerialization['building_id']),
    );
  }

  static final t = StaffCompanyBuildingTable();

  int staff_comapany_id;

  int building_id;

  @override
  String get tableName => 'staff_company_building';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staff_comapany_id': staff_comapany_id,
      'building_id': building_id,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'staff_comapany_id': staff_comapany_id,
      'building_id': building_id,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'staff_comapany_id': staff_comapany_id,
      'building_id': building_id,
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
      case 'staff_comapany_id':
        staff_comapany_id = value;
        return;
      case 'building_id':
        building_id = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  static Future<List<StaffCompanyBuilding>> find(
    _i1.Session session, {
    StaffCompanyBuildingExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<StaffCompanyBuilding>(
      where: where != null ? where(StaffCompanyBuilding.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<StaffCompanyBuilding?> findSingleRow(
    _i1.Session session, {
    StaffCompanyBuildingExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<StaffCompanyBuilding>(
      where: where != null ? where(StaffCompanyBuilding.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<StaffCompanyBuilding?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<StaffCompanyBuilding>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required StaffCompanyBuildingExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<StaffCompanyBuilding>(
      where: where(StaffCompanyBuilding.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    StaffCompanyBuilding row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    StaffCompanyBuilding row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    StaffCompanyBuilding row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    StaffCompanyBuildingExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<StaffCompanyBuilding>(
      where: where != null ? where(StaffCompanyBuilding.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef StaffCompanyBuildingExpressionBuilder = _i1.Expression Function(
    StaffCompanyBuildingTable);

class StaffCompanyBuildingTable extends _i1.Table {
  StaffCompanyBuildingTable() : super(tableName: 'staff_company_building');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final staff_comapany_id = _i1.ColumnInt('staff_comapany_id');

  final building_id = _i1.ColumnInt('building_id');

  @override
  List<_i1.Column> get columns => [
        id,
        staff_comapany_id,
        building_id,
      ];
}

@Deprecated('Use StaffCompanyBuildingTable.t instead.')
StaffCompanyBuildingTable tStaffCompanyBuilding = StaffCompanyBuildingTable();
