/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

library protocol; // ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:serverpod/serverpod.dart' as _i1;
import 'package:serverpod/protocol.dart' as _i2;
import 'building_assignment.dart' as _i3;
import 'member_staff.dart' as _i4;
import 'purpose_category.dart' as _i5;
import 'purpose_sub_category.dart' as _i6;
import 'staff_category.dart' as _i7;
import 'staff_sub_category.dart' as _i8;
import 'visitor.dart' as _i9;
import 'visitor_card.dart' as _i10;
import 'visitor_log.dart' as _i11;
import 'protocol.dart' as _i12;
import 'package:onegate_server/src/generated/purpose_category.dart' as _i13;
import 'package:onegate_server/src/generated/visitor_log.dart' as _i14;
export 'building_assignment.dart';
export 'member_staff.dart';
export 'purpose_category.dart';
export 'purpose_sub_category.dart';
export 'staff_category.dart';
export 'staff_sub_category.dart';
export 'visitor.dart';
export 'visitor_card.dart';
export 'visitor_log.dart';

class Protocol extends _i1.SerializationManagerServer {
  Protocol._();

  factory Protocol() => _instance;

  static final Map<Type, _i1.constructor> customConstructors = {};

  static final Protocol _instance = Protocol._();

  static final targetDatabaseDefinition = _i2.DatabaseDefinition(tables: [
    _i2.TableDefinition(
      name: 'building_assignment',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'building_assignment_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_id',
          columnType: _i2.ColumnType.integer,
          isNullable: true,
          dartType: 'int?',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_log_id',
          columnType: _i2.ColumnType.integer,
          isNullable: true,
          dartType: 'int?',
        ),
        _i2.ColumnDefinition(
          name: 'company_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'building_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'unit_id',
          columnType: _i2.ColumnType.json,
          isNullable: false,
          dartType: 'List<String>',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'building_assignment_fk_0',
          columns: ['visitor_id'],
          referenceTable: 'visitor',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: null,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i2.ForeignKeyDefinition(
          constraintName: 'building_assignment_fk_1',
          columns: ['visitor_log_id'],
          referenceTable: 'visitor_log',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: null,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'building_assignment_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            )
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        )
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'member_staff',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'member_staff_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'name',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'mobile',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'id_proof',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'id_proof_number',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'id_proof_image',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'staff_category_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'staff_sub_category_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'member_staff_fk_0',
          columns: ['staff_category_id'],
          referenceTable: 'staff_categories',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: null,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i2.ForeignKeyDefinition(
          constraintName: 'member_staff_fk_1',
          columns: ['staff_sub_category_id'],
          referenceTable: 'staff_sub_categories',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: null,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'member_staff_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            )
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        )
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'purpose_category',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'purpose_category_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'purpose_category_name',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'purpose_img',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'purpose_category_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            )
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        )
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'purpose_sub_category',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'purpose_sub_category_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'purpose_category_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'purpose_sub_category_name',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'purpose_img',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'purpose_sub_category_fk_0',
          columns: ['purpose_category_id'],
          referenceTable: 'purpose_category',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: null,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        )
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'purpose_sub_category_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            )
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        )
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'staff_categories',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'staff_categories_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'category_name',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'staff_categories_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            )
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        )
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'staff_sub_categories',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'staff_sub_categories_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'staff_category_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'sub_categories_name',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'staff_sub_categories_fk_0',
          columns: ['staff_category_id'],
          referenceTable: 'staff_categories',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: null,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        )
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'staff_sub_categories_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            )
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        )
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'visitor',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'visitor_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'name',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'mobile',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_image',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'visitor_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            )
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        )
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'visitor_card',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'visitor_card_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_card_number',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_card_is_assigned',
          columnType: _i2.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'visitor_card_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            )
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        )
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'visitor_log',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'visitor_log_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_purpose_category_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_purpose_sub_category_id',
          columnType: _i2.ColumnType.integer,
          isNullable: true,
          dartType: 'int?',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_count',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_check_in',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_check_out',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_card_number',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_coming_from',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_card_id',
          columnType: _i2.ColumnType.integer,
          isNullable: true,
          dartType: 'int?',
        ),
        _i2.ColumnDefinition(
          name: 'company_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'is_checked_out',
          columnType: _i2.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'visitor_log_fk_0',
          columns: ['visitor_id'],
          referenceTable: 'visitor',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: null,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i2.ForeignKeyDefinition(
          constraintName: 'visitor_log_fk_1',
          columns: ['visitor_purpose_category_id'],
          referenceTable: 'purpose_category',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: null,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i2.ForeignKeyDefinition(
          constraintName: 'visitor_log_fk_2',
          columns: ['visitor_purpose_sub_category_id'],
          referenceTable: 'purpose_sub_category',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: null,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i2.ForeignKeyDefinition(
          constraintName: 'visitor_log_fk_3',
          columns: ['visitor_card_id'],
          referenceTable: 'visitor_card',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: null,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'visitor_log_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            )
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        )
      ],
      managed: true,
    ),
    ..._i2.Protocol.targetDatabaseDefinition.tables,
  ]);

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;
    if (customConstructors.containsKey(t)) {
      return customConstructors[t]!(data, this) as T;
    }
    if (t == _i3.BuildingAssignment) {
      return _i3.BuildingAssignment.fromJson(data, this) as T;
    }
    if (t == _i4.MemberStaff) {
      return _i4.MemberStaff.fromJson(data, this) as T;
    }
    if (t == _i5.PurposeCategory) {
      return _i5.PurposeCategory.fromJson(data, this) as T;
    }
    if (t == _i6.PurposeSubCategory) {
      return _i6.PurposeSubCategory.fromJson(data, this) as T;
    }
    if (t == _i7.StaffCategory) {
      return _i7.StaffCategory.fromJson(data, this) as T;
    }
    if (t == _i8.StaffSubCategory) {
      return _i8.StaffSubCategory.fromJson(data, this) as T;
    }
    if (t == _i9.Visitor) {
      return _i9.Visitor.fromJson(data, this) as T;
    }
    if (t == _i10.VisitorCard) {
      return _i10.VisitorCard.fromJson(data, this) as T;
    }
    if (t == _i11.VisitorLog) {
      return _i11.VisitorLog.fromJson(data, this) as T;
    }
    if (t == _i1.getType<_i3.BuildingAssignment?>()) {
      return (data != null ? _i3.BuildingAssignment.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i4.MemberStaff?>()) {
      return (data != null ? _i4.MemberStaff.fromJson(data, this) : null) as T;
    }
    if (t == _i1.getType<_i5.PurposeCategory?>()) {
      return (data != null ? _i5.PurposeCategory.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i6.PurposeSubCategory?>()) {
      return (data != null ? _i6.PurposeSubCategory.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i7.StaffCategory?>()) {
      return (data != null ? _i7.StaffCategory.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i8.StaffSubCategory?>()) {
      return (data != null ? _i8.StaffSubCategory.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i9.Visitor?>()) {
      return (data != null ? _i9.Visitor.fromJson(data, this) : null) as T;
    }
    if (t == _i1.getType<_i10.VisitorCard?>()) {
      return (data != null ? _i10.VisitorCard.fromJson(data, this) : null) as T;
    }
    if (t == _i1.getType<_i11.VisitorLog?>()) {
      return (data != null ? _i11.VisitorLog.fromJson(data, this) : null) as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList()
          as dynamic;
    }
    if (t == List<_i12.BuildingAssignment>) {
      return (data as List)
          .map((e) => deserialize<_i12.BuildingAssignment>(e))
          .toList() as dynamic;
    }
    if (t == _i1.getType<List<_i12.BuildingAssignment>?>()) {
      return (data != null
          ? (data as List)
              .map((e) => deserialize<_i12.BuildingAssignment>(e))
              .toList()
          : null) as dynamic;
    }
    if (t == List<_i13.PurposeCategory>) {
      return (data as List)
          .map((e) => deserialize<_i13.PurposeCategory>(e))
          .toList() as dynamic;
    }
    if (t == List<_i14.VisitorLog>) {
      return (data as List).map((e) => deserialize<_i14.VisitorLog>(e)).toList()
          as dynamic;
    }
    try {
      return _i2.Protocol().deserialize<T>(data, t);
    } catch (_) {}
    return super.deserialize<T>(data, t);
  }

  @override
  String? getClassNameForObject(Object data) {
    if (data is _i3.BuildingAssignment) {
      return 'BuildingAssignment';
    }
    if (data is _i4.MemberStaff) {
      return 'MemberStaff';
    }
    if (data is _i5.PurposeCategory) {
      return 'PurposeCategory';
    }
    if (data is _i6.PurposeSubCategory) {
      return 'PurposeSubCategory';
    }
    if (data is _i7.StaffCategory) {
      return 'StaffCategory';
    }
    if (data is _i8.StaffSubCategory) {
      return 'StaffSubCategory';
    }
    if (data is _i9.Visitor) {
      return 'Visitor';
    }
    if (data is _i10.VisitorCard) {
      return 'VisitorCard';
    }
    if (data is _i11.VisitorLog) {
      return 'VisitorLog';
    }
    return super.getClassNameForObject(data);
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    if (data['className'] == 'BuildingAssignment') {
      return deserialize<_i3.BuildingAssignment>(data['data']);
    }
    if (data['className'] == 'MemberStaff') {
      return deserialize<_i4.MemberStaff>(data['data']);
    }
    if (data['className'] == 'PurposeCategory') {
      return deserialize<_i5.PurposeCategory>(data['data']);
    }
    if (data['className'] == 'PurposeSubCategory') {
      return deserialize<_i6.PurposeSubCategory>(data['data']);
    }
    if (data['className'] == 'StaffCategory') {
      return deserialize<_i7.StaffCategory>(data['data']);
    }
    if (data['className'] == 'StaffSubCategory') {
      return deserialize<_i8.StaffSubCategory>(data['data']);
    }
    if (data['className'] == 'Visitor') {
      return deserialize<_i9.Visitor>(data['data']);
    }
    if (data['className'] == 'VisitorCard') {
      return deserialize<_i10.VisitorCard>(data['data']);
    }
    if (data['className'] == 'VisitorLog') {
      return deserialize<_i11.VisitorLog>(data['data']);
    }
    return super.deserializeByClassName(data);
  }

  @override
  _i1.Table? getTableForType(Type t) {
    {
      var table = _i2.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    switch (t) {
      case _i3.BuildingAssignment:
        return _i3.BuildingAssignment.t;
      case _i4.MemberStaff:
        return _i4.MemberStaff.t;
      case _i5.PurposeCategory:
        return _i5.PurposeCategory.t;
      case _i6.PurposeSubCategory:
        return _i6.PurposeSubCategory.t;
      case _i7.StaffCategory:
        return _i7.StaffCategory.t;
      case _i8.StaffSubCategory:
        return _i8.StaffSubCategory.t;
      case _i9.Visitor:
        return _i9.Visitor.t;
      case _i10.VisitorCard:
        return _i10.VisitorCard.t;
      case _i11.VisitorLog:
        return _i11.VisitorLog.t;
    }
    return null;
  }

  @override
  _i2.DatabaseDefinition getTargetDatabaseDefinition() =>
      targetDatabaseDefinition;
}
