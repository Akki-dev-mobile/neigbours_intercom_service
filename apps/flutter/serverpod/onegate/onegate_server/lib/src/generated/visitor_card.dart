/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class VisitorCard extends _i1.TableRow {
  VisitorCard({
    int? id,
    required this.visitor_card_number,
    required this.visitor_card_is_assigned,
  }) : super(id);

  factory VisitorCard.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return VisitorCard(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      visitor_card_number: serializationManager
          .deserialize<String>(jsonSerialization['visitor_card_number']),
      visitor_card_is_assigned: serializationManager
          .deserialize<bool>(jsonSerialization['visitor_card_is_assigned']),
    );
  }

  static final t = VisitorCardTable();

  String visitor_card_number;

  bool visitor_card_is_assigned;

  @override
  String get tableName => 'visitor_card';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitor_card_number': visitor_card_number,
      'visitor_card_is_assigned': visitor_card_is_assigned,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'visitor_card_number': visitor_card_number,
      'visitor_card_is_assigned': visitor_card_is_assigned,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'visitor_card_number': visitor_card_number,
      'visitor_card_is_assigned': visitor_card_is_assigned,
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
      case 'visitor_card_number':
        visitor_card_number = value;
        return;
      case 'visitor_card_is_assigned':
        visitor_card_is_assigned = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  static Future<List<VisitorCard>> find(
    _i1.Session session, {
    VisitorCardExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<VisitorCard>(
      where: where != null ? where(VisitorCard.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<VisitorCard?> findSingleRow(
    _i1.Session session, {
    VisitorCardExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<VisitorCard>(
      where: where != null ? where(VisitorCard.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<VisitorCard?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<VisitorCard>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required VisitorCardExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<VisitorCard>(
      where: where(VisitorCard.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    VisitorCard row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    VisitorCard row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    VisitorCard row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    VisitorCardExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<VisitorCard>(
      where: where != null ? where(VisitorCard.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef VisitorCardExpressionBuilder = _i1.Expression Function(
    VisitorCardTable);

class VisitorCardTable extends _i1.Table {
  VisitorCardTable() : super(tableName: 'visitor_card');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final visitor_card_number = _i1.ColumnString('visitor_card_number');

  final visitor_card_is_assigned = _i1.ColumnBool('visitor_card_is_assigned');

  @override
  List<_i1.Column> get columns => [
        id,
        visitor_card_number,
        visitor_card_is_assigned,
      ];
}

@Deprecated('Use VisitorCardTable.t instead.')
VisitorCardTable tVisitorCard = VisitorCardTable();
