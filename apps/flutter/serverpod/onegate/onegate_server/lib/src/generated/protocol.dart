/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

library protocol; // ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:serverpod/serverpod.dart' as _i1;
import 'package:serverpod/protocol.dart' as _i2;
import 'example.dart' as _i3;
import 'member_staff.dart' as _i4;
import 'member_staff_building_unit.dart' as _i5;
import 'member_staff_categories.dart' as _i6;
import 'member_staff_sub_categories.dart' as _i7;
import 'protocol.dart' as _i8;
export 'example.dart';
export 'member_staff.dart';
export 'member_staff_building_unit.dart';
export 'member_staff_categories.dart';
export 'member_staff_sub_categories.dart';

class Protocol extends _i1.SerializationManagerServer {
  Protocol._();

  factory Protocol() => _instance;

  static final Map<Type, _i1.constructor> customConstructors = {};

  static final Protocol _instance = Protocol._();

  static final targetDatabaseDefinition = _i2.DatabaseDefinition(tables: [
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
          name: 'category_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'sub_category_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'company_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'id_proof_type',
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
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'member_staff_fk_0',
          columns: ['category_id'],
          referenceTable: 'member_staff_categories',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: null,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i2.ForeignKeyDefinition(
          constraintName: 'member_staff_fk_1',
          columns: ['sub_category_id'],
          referenceTable: 'member_staff_sub_categories',
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
      name: 'member_staff_building_unit',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault:
              'nextval(\'member_staff_building_unit_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'member_staff_id',
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
          name: 'building_unit_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'member_staff_building_unit_fk_0',
          columns: ['member_staff_id'],
          referenceTable: 'member_staff',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: null,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        )
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'member_staff_building_unit_pkey',
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
      name: 'member_staff_categories',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault:
              'nextval(\'member_staff_categories_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'name',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'member_staff_categories_pkey',
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
      name: 'member_staff_sub_categories',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault:
              'nextval(\'member_staff_sub_categories_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'name',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'category_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'member_staff_sub_categories_fk_0',
          columns: ['category_id'],
          referenceTable: 'member_staff_categories',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: null,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        )
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'member_staff_sub_categories_pkey',
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
    if (t == _i3.Example) {
      return _i3.Example.fromJson(data, this) as T;
    }
    if (t == _i4.MemberStaff) {
      return _i4.MemberStaff.fromJson(data, this) as T;
    }
    if (t == _i5.MemberStaffBuildingUnit) {
      return _i5.MemberStaffBuildingUnit.fromJson(data, this) as T;
    }
    if (t == _i6.MemberStaffCategories) {
      return _i6.MemberStaffCategories.fromJson(data, this) as T;
    }
    if (t == _i7.MemberStaffSubCategories) {
      return _i7.MemberStaffSubCategories.fromJson(data, this) as T;
    }
    if (t == _i1.getType<_i3.Example?>()) {
      return (data != null ? _i3.Example.fromJson(data, this) : null) as T;
    }
    if (t == _i1.getType<_i4.MemberStaff?>()) {
      return (data != null ? _i4.MemberStaff.fromJson(data, this) : null) as T;
    }
    if (t == _i1.getType<_i5.MemberStaffBuildingUnit?>()) {
      return (data != null
          ? _i5.MemberStaffBuildingUnit.fromJson(data, this)
          : null) as T;
    }
    if (t == _i1.getType<_i6.MemberStaffCategories?>()) {
      return (data != null
          ? _i6.MemberStaffCategories.fromJson(data, this)
          : null) as T;
    }
    if (t == _i1.getType<_i7.MemberStaffSubCategories?>()) {
      return (data != null
          ? _i7.MemberStaffSubCategories.fromJson(data, this)
          : null) as T;
    }
    if (t == _i1.getType<List<_i8.MemberStaffBuildingUnit>?>()) {
      return (data != null
          ? (data as List)
              .map((e) => deserialize<_i8.MemberStaffBuildingUnit>(e))
              .toList()
          : null) as dynamic;
    }
    try {
      return _i2.Protocol().deserialize<T>(data, t);
    } catch (_) {}
    return super.deserialize<T>(data, t);
  }

  @override
  String? getClassNameForObject(Object data) {
    if (data is _i3.Example) {
      return 'Example';
    }
    if (data is _i4.MemberStaff) {
      return 'MemberStaff';
    }
    if (data is _i5.MemberStaffBuildingUnit) {
      return 'MemberStaffBuildingUnit';
    }
    if (data is _i6.MemberStaffCategories) {
      return 'MemberStaffCategories';
    }
    if (data is _i7.MemberStaffSubCategories) {
      return 'MemberStaffSubCategories';
    }
    return super.getClassNameForObject(data);
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    if (data['className'] == 'Example') {
      return deserialize<_i3.Example>(data['data']);
    }
    if (data['className'] == 'MemberStaff') {
      return deserialize<_i4.MemberStaff>(data['data']);
    }
    if (data['className'] == 'MemberStaffBuildingUnit') {
      return deserialize<_i5.MemberStaffBuildingUnit>(data['data']);
    }
    if (data['className'] == 'MemberStaffCategories') {
      return deserialize<_i6.MemberStaffCategories>(data['data']);
    }
    if (data['className'] == 'MemberStaffSubCategories') {
      return deserialize<_i7.MemberStaffSubCategories>(data['data']);
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
      case _i4.MemberStaff:
        return _i4.MemberStaff.t;
      case _i5.MemberStaffBuildingUnit:
        return _i5.MemberStaffBuildingUnit.t;
      case _i6.MemberStaffCategories:
        return _i6.MemberStaffCategories.t;
      case _i7.MemberStaffSubCategories:
        return _i7.MemberStaffSubCategories.t;
    }
    return null;
  }

  @override
  _i2.DatabaseDefinition getTargetDatabaseDefinition() =>
      targetDatabaseDefinition;
}
