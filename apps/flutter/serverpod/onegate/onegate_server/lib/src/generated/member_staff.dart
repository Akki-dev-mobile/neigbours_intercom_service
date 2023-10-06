/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;
import 'protocol.dart' as _i2;

class MemberStaff extends _i1.TableRow {
  MemberStaff({
    int? id,
    required this.name,
    required this.category_id,
    required this.sub_category_id,
    required this.company_id,
    required this.id_proof_type,
    required this.id_proof_number,
    required this.id_proof_image,
    this.member_staff_building_unit,
  }) : super(id);

  factory MemberStaff.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return MemberStaff(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      name: serializationManager.deserialize<String>(jsonSerialization['name']),
      category_id: serializationManager
          .deserialize<int>(jsonSerialization['category_id']),
      sub_category_id: serializationManager
          .deserialize<int>(jsonSerialization['sub_category_id']),
      company_id: serializationManager
          .deserialize<int>(jsonSerialization['company_id']),
      id_proof_type: serializationManager
          .deserialize<String>(jsonSerialization['id_proof_type']),
      id_proof_number: serializationManager
          .deserialize<String>(jsonSerialization['id_proof_number']),
      id_proof_image: serializationManager
          .deserialize<String>(jsonSerialization['id_proof_image']),
      member_staff_building_unit:
          serializationManager.deserialize<List<_i2.MemberStaffBuildingUnit>?>(
              jsonSerialization['member_staff_building_unit']),
    );
  }

  static final t = MemberStaffTable();

  String name;

  int category_id;

  int sub_category_id;

  int company_id;

  String id_proof_type;

  String id_proof_number;

  String id_proof_image;

  List<_i2.MemberStaffBuildingUnit>? member_staff_building_unit;

  @override
  String get tableName => 'member_staff';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category_id': category_id,
      'sub_category_id': sub_category_id,
      'company_id': company_id,
      'id_proof_type': id_proof_type,
      'id_proof_number': id_proof_number,
      'id_proof_image': id_proof_image,
      'member_staff_building_unit': member_staff_building_unit,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'name': name,
      'category_id': category_id,
      'sub_category_id': sub_category_id,
      'company_id': company_id,
      'id_proof_type': id_proof_type,
      'id_proof_number': id_proof_number,
      'id_proof_image': id_proof_image,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'name': name,
      'category_id': category_id,
      'sub_category_id': sub_category_id,
      'company_id': company_id,
      'id_proof_type': id_proof_type,
      'id_proof_number': id_proof_number,
      'id_proof_image': id_proof_image,
      'member_staff_building_unit': member_staff_building_unit,
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
      case 'name':
        name = value;
        return;
      case 'category_id':
        category_id = value;
        return;
      case 'sub_category_id':
        sub_category_id = value;
        return;
      case 'company_id':
        company_id = value;
        return;
      case 'id_proof_type':
        id_proof_type = value;
        return;
      case 'id_proof_number':
        id_proof_number = value;
        return;
      case 'id_proof_image':
        id_proof_image = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  static Future<List<MemberStaff>> find(
    _i1.Session session, {
    MemberStaffExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<MemberStaff>(
      where: where != null ? where(MemberStaff.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<MemberStaff?> findSingleRow(
    _i1.Session session, {
    MemberStaffExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<MemberStaff>(
      where: where != null ? where(MemberStaff.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<MemberStaff?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<MemberStaff>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required MemberStaffExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<MemberStaff>(
      where: where(MemberStaff.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    MemberStaff row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    MemberStaff row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    MemberStaff row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    MemberStaffExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<MemberStaff>(
      where: where != null ? where(MemberStaff.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef MemberStaffExpressionBuilder = _i1.Expression Function(
    MemberStaffTable);

class MemberStaffTable extends _i1.Table {
  MemberStaffTable() : super(tableName: 'member_staff');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final name = _i1.ColumnString('name');

  final category_id = _i1.ColumnInt('category_id');

  final sub_category_id = _i1.ColumnInt('sub_category_id');

  final company_id = _i1.ColumnInt('company_id');

  final id_proof_type = _i1.ColumnString('id_proof_type');

  final id_proof_number = _i1.ColumnString('id_proof_number');

  final id_proof_image = _i1.ColumnString('id_proof_image');

  @override
  List<_i1.Column> get columns => [
        id,
        name,
        category_id,
        sub_category_id,
        company_id,
        id_proof_type,
        id_proof_number,
        id_proof_image,
      ];
}

@Deprecated('Use MemberStaffTable.t instead.')
MemberStaffTable tMemberStaff = MemberStaffTable();
