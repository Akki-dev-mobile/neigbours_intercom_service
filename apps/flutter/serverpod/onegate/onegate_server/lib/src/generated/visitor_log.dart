/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;
import 'protocol.dart' as _i2;

class VisitorLog extends _i1.TableRow {
  VisitorLog({
    int? id,
    required this.visitor_id,
    this.visitor,
    required this.visitor_purpose_category_id,
    this.visitor_purpose_sub_category_id,
    this.visitor_building_assignment,
    required this.visitor_count,
    required this.visitor_check_in,
    this.visitor_check_out,
    this.visitor_card_number,
    this.visitor_coming_from,
    this.visitor_card_id,
    required this.company_id,
  }) : super(id);

  factory VisitorLog.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return VisitorLog(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      visitor_id: serializationManager
          .deserialize<int>(jsonSerialization['visitor_id']),
      visitor: serializationManager
          .deserialize<_i2.Visitor?>(jsonSerialization['visitor']),
      visitor_purpose_category_id: serializationManager
          .deserialize<int>(jsonSerialization['visitor_purpose_category_id']),
      visitor_purpose_sub_category_id: serializationManager.deserialize<int?>(
          jsonSerialization['visitor_purpose_sub_category_id']),
      visitor_building_assignment:
          serializationManager.deserialize<List<_i2.BuildingAssignment>?>(
              jsonSerialization['visitor_building_assignment']),
      visitor_count: serializationManager
          .deserialize<int>(jsonSerialization['visitor_count']),
      visitor_check_in: serializationManager
          .deserialize<DateTime>(jsonSerialization['visitor_check_in']),
      visitor_check_out: serializationManager
          .deserialize<DateTime?>(jsonSerialization['visitor_check_out']),
      visitor_card_number: serializationManager
          .deserialize<String?>(jsonSerialization['visitor_card_number']),
      visitor_coming_from: serializationManager
          .deserialize<String?>(jsonSerialization['visitor_coming_from']),
      visitor_card_id: serializationManager
          .deserialize<int?>(jsonSerialization['visitor_card_id']),
      company_id: serializationManager
          .deserialize<int>(jsonSerialization['company_id']),
    );
  }

  static final t = VisitorLogTable();

  int visitor_id;

  _i2.Visitor? visitor;

  int visitor_purpose_category_id;

  int? visitor_purpose_sub_category_id;

  List<_i2.BuildingAssignment>? visitor_building_assignment;

  int visitor_count;

  DateTime visitor_check_in;

  DateTime? visitor_check_out;

  String? visitor_card_number;

  String? visitor_coming_from;

  int? visitor_card_id;

  int company_id;

  @override
  String get tableName => 'visitor_log';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'visitor': visitor,
      'visitor_purpose_category_id': visitor_purpose_category_id,
      'visitor_purpose_sub_category_id': visitor_purpose_sub_category_id,
      'visitor_building_assignment': visitor_building_assignment,
      'visitor_count': visitor_count,
      'visitor_check_in': visitor_check_in,
      'visitor_check_out': visitor_check_out,
      'visitor_card_number': visitor_card_number,
      'visitor_coming_from': visitor_coming_from,
      'visitor_card_id': visitor_card_id,
      'company_id': company_id,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'visitor_purpose_category_id': visitor_purpose_category_id,
      'visitor_purpose_sub_category_id': visitor_purpose_sub_category_id,
      'visitor_count': visitor_count,
      'visitor_check_in': visitor_check_in,
      'visitor_check_out': visitor_check_out,
      'visitor_card_number': visitor_card_number,
      'visitor_coming_from': visitor_coming_from,
      'visitor_card_id': visitor_card_id,
      'company_id': company_id,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'visitor': visitor,
      'visitor_purpose_category_id': visitor_purpose_category_id,
      'visitor_purpose_sub_category_id': visitor_purpose_sub_category_id,
      'visitor_building_assignment': visitor_building_assignment,
      'visitor_count': visitor_count,
      'visitor_check_in': visitor_check_in,
      'visitor_check_out': visitor_check_out,
      'visitor_card_number': visitor_card_number,
      'visitor_coming_from': visitor_coming_from,
      'visitor_card_id': visitor_card_id,
      'company_id': company_id,
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
      case 'visitor_purpose_category_id':
        visitor_purpose_category_id = value;
        return;
      case 'visitor_purpose_sub_category_id':
        visitor_purpose_sub_category_id = value;
        return;
      case 'visitor_count':
        visitor_count = value;
        return;
      case 'visitor_check_in':
        visitor_check_in = value;
        return;
      case 'visitor_check_out':
        visitor_check_out = value;
        return;
      case 'visitor_card_number':
        visitor_card_number = value;
        return;
      case 'visitor_coming_from':
        visitor_coming_from = value;
        return;
      case 'visitor_card_id':
        visitor_card_id = value;
        return;
      case 'company_id':
        company_id = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  static Future<List<VisitorLog>> find(
    _i1.Session session, {
    VisitorLogExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<VisitorLog>(
      where: where != null ? where(VisitorLog.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<VisitorLog?> findSingleRow(
    _i1.Session session, {
    VisitorLogExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<VisitorLog>(
      where: where != null ? where(VisitorLog.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<VisitorLog?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<VisitorLog>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required VisitorLogExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<VisitorLog>(
      where: where(VisitorLog.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    VisitorLog row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    VisitorLog row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    VisitorLog row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    VisitorLogExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<VisitorLog>(
      where: where != null ? where(VisitorLog.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef VisitorLogExpressionBuilder = _i1.Expression Function(VisitorLogTable);

class VisitorLogTable extends _i1.Table {
  VisitorLogTable() : super(tableName: 'visitor_log');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final visitor_id = _i1.ColumnInt('visitor_id');

  final visitor_purpose_category_id =
      _i1.ColumnInt('visitor_purpose_category_id');

  final visitor_purpose_sub_category_id =
      _i1.ColumnInt('visitor_purpose_sub_category_id');

  final visitor_count = _i1.ColumnInt('visitor_count');

  final visitor_check_in = _i1.ColumnDateTime('visitor_check_in');

  final visitor_check_out = _i1.ColumnDateTime('visitor_check_out');

  final visitor_card_number = _i1.ColumnString('visitor_card_number');

  final visitor_coming_from = _i1.ColumnString('visitor_coming_from');

  final visitor_card_id = _i1.ColumnInt('visitor_card_id');

  final company_id = _i1.ColumnInt('company_id');

  @override
  List<_i1.Column> get columns => [
        id,
        visitor_id,
        visitor_purpose_category_id,
        visitor_purpose_sub_category_id,
        visitor_count,
        visitor_check_in,
        visitor_check_out,
        visitor_card_number,
        visitor_coming_from,
        visitor_card_id,
        company_id,
      ];
}

@Deprecated('Use VisitorLogTable.t instead.')
VisitorLogTable tVisitorLog = VisitorLogTable();
