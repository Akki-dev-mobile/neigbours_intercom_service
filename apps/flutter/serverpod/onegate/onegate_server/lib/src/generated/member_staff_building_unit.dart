/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class MemberStaffBuildingUnit extends _i1.TableRow {
  MemberStaffBuildingUnit({
    int? id,
    required this.member_staff_id,
    required this.building_id,
    required this.building_unit_id,
  }) : super(id);

  factory MemberStaffBuildingUnit.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return MemberStaffBuildingUnit(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      member_staff_id: serializationManager
          .deserialize<int>(jsonSerialization['member_staff_id']),
      building_id: serializationManager
          .deserialize<int>(jsonSerialization['building_id']),
      building_unit_id: serializationManager
          .deserialize<int>(jsonSerialization['building_unit_id']),
    );
  }

  static final t = MemberStaffBuildingUnitTable();

  int member_staff_id;

  int building_id;

  int building_unit_id;

  @override
  String get tableName => 'member_staff_building_unit';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'member_staff_id': member_staff_id,
      'building_id': building_id,
      'building_unit_id': building_unit_id,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'member_staff_id': member_staff_id,
      'building_id': building_id,
      'building_unit_id': building_unit_id,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'member_staff_id': member_staff_id,
      'building_id': building_id,
      'building_unit_id': building_unit_id,
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
      case 'member_staff_id':
        member_staff_id = value;
        return;
      case 'building_id':
        building_id = value;
        return;
      case 'building_unit_id':
        building_unit_id = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  static Future<List<MemberStaffBuildingUnit>> find(
    _i1.Session session, {
    MemberStaffBuildingUnitExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<MemberStaffBuildingUnit>(
      where: where != null ? where(MemberStaffBuildingUnit.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<MemberStaffBuildingUnit?> findSingleRow(
    _i1.Session session, {
    MemberStaffBuildingUnitExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<MemberStaffBuildingUnit>(
      where: where != null ? where(MemberStaffBuildingUnit.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<MemberStaffBuildingUnit?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<MemberStaffBuildingUnit>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required MemberStaffBuildingUnitExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<MemberStaffBuildingUnit>(
      where: where(MemberStaffBuildingUnit.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    MemberStaffBuildingUnit row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    MemberStaffBuildingUnit row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    MemberStaffBuildingUnit row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    MemberStaffBuildingUnitExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<MemberStaffBuildingUnit>(
      where: where != null ? where(MemberStaffBuildingUnit.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef MemberStaffBuildingUnitExpressionBuilder = _i1.Expression Function(
    MemberStaffBuildingUnitTable);

class MemberStaffBuildingUnitTable extends _i1.Table {
  MemberStaffBuildingUnitTable()
      : super(tableName: 'member_staff_building_unit');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final member_staff_id = _i1.ColumnInt('member_staff_id');

  final building_id = _i1.ColumnInt('building_id');

  final building_unit_id = _i1.ColumnInt('building_unit_id');

  @override
  List<_i1.Column> get columns => [
        id,
        member_staff_id,
        building_id,
        building_unit_id,
      ];
}

@Deprecated('Use MemberStaffBuildingUnitTable.t instead.')
MemberStaffBuildingUnitTable tMemberStaffBuildingUnit =
    MemberStaffBuildingUnitTable();
