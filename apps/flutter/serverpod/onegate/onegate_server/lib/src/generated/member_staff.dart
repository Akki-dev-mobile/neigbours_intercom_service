/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class MemberStaff extends _i1.TableRow {
  MemberStaff({
    int? id,
    required this.name,
    required this.phone,
    required this.dob,
    required this.gender,
    required this.member_category_id,
    required this.member_sub_category_id,
    required this.email,
    required this.address,
    required this.verification_type_id,
    required this.verification_number,
    required this.profile_image_url,
    required this.status,
    required this.deleted_by,
    required this.created_at,
    required this.created_by,
    required this.updated_at,
    required this.updated_by,
  }) : super(id);

  factory MemberStaff.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return MemberStaff(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      name: serializationManager.deserialize<String>(jsonSerialization['name']),
      phone:
          serializationManager.deserialize<String>(jsonSerialization['phone']),
      dob: serializationManager.deserialize<DateTime>(jsonSerialization['dob']),
      gender:
          serializationManager.deserialize<String>(jsonSerialization['gender']),
      member_category_id: serializationManager
          .deserialize<int>(jsonSerialization['member_category_id']),
      member_sub_category_id: serializationManager
          .deserialize<int>(jsonSerialization['member_sub_category_id']),
      email:
          serializationManager.deserialize<String>(jsonSerialization['email']),
      address: serializationManager
          .deserialize<String>(jsonSerialization['address']),
      verification_type_id: serializationManager
          .deserialize<int>(jsonSerialization['verification_type_id']),
      verification_number: serializationManager
          .deserialize<String>(jsonSerialization['verification_number']),
      profile_image_url: serializationManager
          .deserialize<String>(jsonSerialization['profile_image_url']),
      status:
          serializationManager.deserialize<String>(jsonSerialization['status']),
      deleted_by: serializationManager
          .deserialize<String>(jsonSerialization['deleted_by']),
      created_at: serializationManager
          .deserialize<DateTime>(jsonSerialization['created_at']),
      created_by: serializationManager
          .deserialize<String>(jsonSerialization['created_by']),
      updated_at: serializationManager
          .deserialize<DateTime>(jsonSerialization['updated_at']),
      updated_by: serializationManager
          .deserialize<String>(jsonSerialization['updated_by']),
    );
  }

  static final t = MemberStaffTable();

  String name;

  String phone;

  DateTime dob;

  String gender;

  int member_category_id;

  int member_sub_category_id;

  String email;

  String address;

  int verification_type_id;

  String verification_number;

  String profile_image_url;

  String status;

  String deleted_by;

  DateTime created_at;

  String created_by;

  DateTime updated_at;

  String updated_by;

  @override
  String get tableName => 'member_staff';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'dob': dob,
      'gender': gender,
      'member_category_id': member_category_id,
      'member_sub_category_id': member_sub_category_id,
      'email': email,
      'address': address,
      'verification_type_id': verification_type_id,
      'verification_number': verification_number,
      'profile_image_url': profile_image_url,
      'status': status,
      'deleted_by': deleted_by,
      'created_at': created_at,
      'created_by': created_by,
      'updated_at': updated_at,
      'updated_by': updated_by,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'dob': dob,
      'gender': gender,
      'member_category_id': member_category_id,
      'member_sub_category_id': member_sub_category_id,
      'email': email,
      'address': address,
      'verification_type_id': verification_type_id,
      'verification_number': verification_number,
      'profile_image_url': profile_image_url,
      'status': status,
      'deleted_by': deleted_by,
      'created_at': created_at,
      'created_by': created_by,
      'updated_at': updated_at,
      'updated_by': updated_by,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'dob': dob,
      'gender': gender,
      'member_category_id': member_category_id,
      'member_sub_category_id': member_sub_category_id,
      'email': email,
      'address': address,
      'verification_type_id': verification_type_id,
      'verification_number': verification_number,
      'profile_image_url': profile_image_url,
      'status': status,
      'deleted_by': deleted_by,
      'created_at': created_at,
      'created_by': created_by,
      'updated_at': updated_at,
      'updated_by': updated_by,
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
      case 'phone':
        phone = value;
        return;
      case 'dob':
        dob = value;
        return;
      case 'gender':
        gender = value;
        return;
      case 'member_category_id':
        member_category_id = value;
        return;
      case 'member_sub_category_id':
        member_sub_category_id = value;
        return;
      case 'email':
        email = value;
        return;
      case 'address':
        address = value;
        return;
      case 'verification_type_id':
        verification_type_id = value;
        return;
      case 'verification_number':
        verification_number = value;
        return;
      case 'profile_image_url':
        profile_image_url = value;
        return;
      case 'status':
        status = value;
        return;
      case 'deleted_by':
        deleted_by = value;
        return;
      case 'created_at':
        created_at = value;
        return;
      case 'created_by':
        created_by = value;
        return;
      case 'updated_at':
        updated_at = value;
        return;
      case 'updated_by':
        updated_by = value;
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

  final phone = _i1.ColumnString('phone');

  final dob = _i1.ColumnDateTime('dob');

  final gender = _i1.ColumnString('gender');

  final member_category_id = _i1.ColumnInt('member_category_id');

  final member_sub_category_id = _i1.ColumnInt('member_sub_category_id');

  final email = _i1.ColumnString('email');

  final address = _i1.ColumnString('address');

  final verification_type_id = _i1.ColumnInt('verification_type_id');

  final verification_number = _i1.ColumnString('verification_number');

  final profile_image_url = _i1.ColumnString('profile_image_url');

  final status = _i1.ColumnString('status');

  final deleted_by = _i1.ColumnString('deleted_by');

  final created_at = _i1.ColumnDateTime('created_at');

  final created_by = _i1.ColumnString('created_by');

  final updated_at = _i1.ColumnDateTime('updated_at');

  final updated_by = _i1.ColumnString('updated_by');

  @override
  List<_i1.Column> get columns => [
        id,
        name,
        phone,
        dob,
        gender,
        member_category_id,
        member_sub_category_id,
        email,
        address,
        verification_type_id,
        verification_number,
        profile_image_url,
        status,
        deleted_by,
        created_at,
        created_by,
        updated_at,
        updated_by,
      ];
}

@Deprecated('Use MemberStaffTable.t instead.')
MemberStaffTable tMemberStaff = MemberStaffTable();
