/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class Visitors extends _i1.TableRow {
  Visitors({
    int? id,
    required this.mobile,
    required this.member_category_id,
    required this.visitor_img_url,
    required this.in_gate_id,
    required this.in_time,
    required this.out_gate_id,
    required this.out_time,
    required this.permission_status,
    required this.visitor_count,
    required this.passcode,
    required this.created_at,
    required this.created_by,
    required this.updated_at,
    required this.updated_by,
  }) : super(id);

  factory Visitors.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return Visitors(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      mobile:
          serializationManager.deserialize<String>(jsonSerialization['mobile']),
      member_category_id: serializationManager
          .deserialize<int>(jsonSerialization['member_category_id']),
      visitor_img_url: serializationManager
          .deserialize<String>(jsonSerialization['visitor_img_url']),
      in_gate_id: serializationManager
          .deserialize<int>(jsonSerialization['in_gate_id']),
      in_time: serializationManager
          .deserialize<DateTime>(jsonSerialization['in_time']),
      out_gate_id: serializationManager
          .deserialize<int>(jsonSerialization['out_gate_id']),
      out_time: serializationManager
          .deserialize<DateTime>(jsonSerialization['out_time']),
      permission_status: serializationManager
          .deserialize<String>(jsonSerialization['permission_status']),
      visitor_count: serializationManager
          .deserialize<int>(jsonSerialization['visitor_count']),
      passcode: serializationManager
          .deserialize<String>(jsonSerialization['passcode']),
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

  static final t = VisitorsTable();

  String mobile;

  int member_category_id;

  String visitor_img_url;

  int in_gate_id;

  DateTime in_time;

  int out_gate_id;

  DateTime out_time;

  String permission_status;

  int visitor_count;

  String passcode;

  DateTime created_at;

  String created_by;

  DateTime updated_at;

  String updated_by;

  @override
  String get tableName => 'visitors';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mobile': mobile,
      'member_category_id': member_category_id,
      'visitor_img_url': visitor_img_url,
      'in_gate_id': in_gate_id,
      'in_time': in_time,
      'out_gate_id': out_gate_id,
      'out_time': out_time,
      'permission_status': permission_status,
      'visitor_count': visitor_count,
      'passcode': passcode,
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
      'mobile': mobile,
      'member_category_id': member_category_id,
      'visitor_img_url': visitor_img_url,
      'in_gate_id': in_gate_id,
      'in_time': in_time,
      'out_gate_id': out_gate_id,
      'out_time': out_time,
      'permission_status': permission_status,
      'visitor_count': visitor_count,
      'passcode': passcode,
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
      'mobile': mobile,
      'member_category_id': member_category_id,
      'visitor_img_url': visitor_img_url,
      'in_gate_id': in_gate_id,
      'in_time': in_time,
      'out_gate_id': out_gate_id,
      'out_time': out_time,
      'permission_status': permission_status,
      'visitor_count': visitor_count,
      'passcode': passcode,
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
      case 'mobile':
        mobile = value;
        return;
      case 'member_category_id':
        member_category_id = value;
        return;
      case 'visitor_img_url':
        visitor_img_url = value;
        return;
      case 'in_gate_id':
        in_gate_id = value;
        return;
      case 'in_time':
        in_time = value;
        return;
      case 'out_gate_id':
        out_gate_id = value;
        return;
      case 'out_time':
        out_time = value;
        return;
      case 'permission_status':
        permission_status = value;
        return;
      case 'visitor_count':
        visitor_count = value;
        return;
      case 'passcode':
        passcode = value;
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

  static Future<List<Visitors>> find(
    _i1.Session session, {
    VisitorsExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<Visitors>(
      where: where != null ? where(Visitors.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<Visitors?> findSingleRow(
    _i1.Session session, {
    VisitorsExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<Visitors>(
      where: where != null ? where(Visitors.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<Visitors?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<Visitors>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required VisitorsExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<Visitors>(
      where: where(Visitors.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    Visitors row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    Visitors row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    Visitors row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    VisitorsExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<Visitors>(
      where: where != null ? where(Visitors.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef VisitorsExpressionBuilder = _i1.Expression Function(VisitorsTable);

class VisitorsTable extends _i1.Table {
  VisitorsTable() : super(tableName: 'visitors');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final mobile = _i1.ColumnString('mobile');

  final member_category_id = _i1.ColumnInt('member_category_id');

  final visitor_img_url = _i1.ColumnString('visitor_img_url');

  final in_gate_id = _i1.ColumnInt('in_gate_id');

  final in_time = _i1.ColumnDateTime('in_time');

  final out_gate_id = _i1.ColumnInt('out_gate_id');

  final out_time = _i1.ColumnDateTime('out_time');

  final permission_status = _i1.ColumnString('permission_status');

  final visitor_count = _i1.ColumnInt('visitor_count');

  final passcode = _i1.ColumnString('passcode');

  final created_at = _i1.ColumnDateTime('created_at');

  final created_by = _i1.ColumnString('created_by');

  final updated_at = _i1.ColumnDateTime('updated_at');

  final updated_by = _i1.ColumnString('updated_by');

  @override
  List<_i1.Column> get columns => [
        id,
        mobile,
        member_category_id,
        visitor_img_url,
        in_gate_id,
        in_time,
        out_gate_id,
        out_time,
        permission_status,
        visitor_count,
        passcode,
        created_at,
        created_by,
        updated_at,
        updated_by,
      ];
}

@Deprecated('Use VisitorsTable.t instead.')
VisitorsTable tVisitors = VisitorsTable();
