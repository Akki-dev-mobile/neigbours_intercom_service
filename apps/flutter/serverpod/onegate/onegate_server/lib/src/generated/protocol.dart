/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

library protocol; // ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:serverpod/serverpod.dart' as _i1;
import 'package:serverpod/protocol.dart' as _i2;
import 'delivery_visitors.dart' as _i3;
import 'example.dart' as _i4;
import 'guest_visitors.dart' as _i5;
import 'member_categories.dart' as _i6;
import 'member_staff.dart' as _i7;
import 'member_sub_categories.dart' as _i8;
import 'staff_building_units.dart' as _i9;
import 'staff_companies.dart' as _i10;
import 'staff_company_building.dart' as _i11;
import 'staff_visitors.dart' as _i12;
import 'transport_visitors.dart' as _i13;
import 'vendor_visitors.dart' as _i14;
import 'verification_types.dart' as _i15;
import 'visitor_building_units.dart' as _i16;
import 'visitor_companies.dart' as _i17;
import 'visitor_company_buildings.dart' as _i18;
import 'visitors.dart' as _i19;
export 'delivery_visitors.dart';
export 'example.dart';
export 'guest_visitors.dart';
export 'member_categories.dart';
export 'member_staff.dart';
export 'member_sub_categories.dart';
export 'staff_building_units.dart';
export 'staff_companies.dart';
export 'staff_company_building.dart';
export 'staff_visitors.dart';
export 'transport_visitors.dart';
export 'vendor_visitors.dart';
export 'verification_types.dart';
export 'visitor_building_units.dart';
export 'visitor_companies.dart';
export 'visitor_company_buildings.dart';
export 'visitors.dart';

class Protocol extends _i1.SerializationManagerServer {
  Protocol._();

  factory Protocol() => _instance;

  static final Map<Type, _i1.constructor> customConstructors = {};

  static final Protocol _instance = Protocol._();

  static final targetDatabaseDefinition = _i2.DatabaseDefinition(tables: [
    _i2.TableDefinition(
      name: 'delivery_visitors',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'delivery_visitors_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'delivery_person_name',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'delivery_comapny',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'delivery_visitors_pkey',
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
      name: 'guest_visitors',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'guest_visitors_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'guest_name',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'guest_coming_from',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'guest_count',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'guest_visitors_pkey',
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
      name: 'member_categories',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'member_categories_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'name',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'created_at',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'updated_at',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'member_categories_pkey',
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
          name: 'phone',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'dob',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'gender',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'member_category_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'member_sub_category_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'email',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'address',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'verification_type_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'verification_number',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'profile_image_url',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'deleted_by',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'created_at',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'created_by',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'updated_at',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'updated_by',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [],
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
      name: 'member_sub_categories',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'member_sub_categories_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'name',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'member_category_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'created_at',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'updated_at',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'member_sub_categories_pkey',
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
      name: 'staff_building_units',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'staff_building_units_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'staff_company_building_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'unit_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'staff_building_units_pkey',
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
      name: 'staff_companies',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'staff_companies_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'member_staff_id',
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
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'staff_companies_pkey',
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
      name: 'staff_company_building',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'staff_company_building_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'staff_comapany_id',
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
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'staff_company_building_pkey',
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
      name: 'staff_visitors',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'staff_visitors_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'member_sub_category_id',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'staff_visitors_pkey',
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
      name: 'transport_visitors',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'transport_visitors_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'driver_name',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'transport_visitors_pkey',
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
      name: 'vendor_visitors',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'vendor_visitors_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'vendor_name',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'member_sub_category_id',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'vendor_visitors_pkey',
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
      name: 'verification_types',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'verification_types_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'name',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'created_at',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'updated_at',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'verification_types_pkey',
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
      name: 'visitor_building_units',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'visitor_building_units_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_company_building_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'unit_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'visitor_building_units_pkey',
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
      name: 'visitor_companies',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'visitor_companies_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_id',
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
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'visitor_companies_pkey',
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
      name: 'visitor_company_buildings',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault:
              'nextval(\'visitor_company_buildings_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_company_id',
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
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'visitor_company_buildings_pkey',
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
      name: 'visitors',
      schema: 'public',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'visitors_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'mobile',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'member_category_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_img_url',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'in_gate_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'in_time',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'out_gate_id',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'out_time',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'permission_status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'visitor_count',
          columnType: _i2.ColumnType.integer,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'passcode',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'created_at',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'created_by',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'updated_at',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'updated_by',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'visitors_pkey',
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
    if (t == _i3.DeliveryVisitors) {
      return _i3.DeliveryVisitors.fromJson(data, this) as T;
    }
    if (t == _i4.Example) {
      return _i4.Example.fromJson(data, this) as T;
    }
    if (t == _i5.GuestVisitors) {
      return _i5.GuestVisitors.fromJson(data, this) as T;
    }
    if (t == _i6.MemberCategories) {
      return _i6.MemberCategories.fromJson(data, this) as T;
    }
    if (t == _i7.MemberStaff) {
      return _i7.MemberStaff.fromJson(data, this) as T;
    }
    if (t == _i8.MemberSubCategories) {
      return _i8.MemberSubCategories.fromJson(data, this) as T;
    }
    if (t == _i9.StaffBuildingUnits) {
      return _i9.StaffBuildingUnits.fromJson(data, this) as T;
    }
    if (t == _i10.StaffCompanies) {
      return _i10.StaffCompanies.fromJson(data, this) as T;
    }
    if (t == _i11.StaffCompanyBuilding) {
      return _i11.StaffCompanyBuilding.fromJson(data, this) as T;
    }
    if (t == _i12.StaffVisitors) {
      return _i12.StaffVisitors.fromJson(data, this) as T;
    }
    if (t == _i13.TransportVisitors) {
      return _i13.TransportVisitors.fromJson(data, this) as T;
    }
    if (t == _i14.VendorVisitors) {
      return _i14.VendorVisitors.fromJson(data, this) as T;
    }
    if (t == _i15.VerificationTypes) {
      return _i15.VerificationTypes.fromJson(data, this) as T;
    }
    if (t == _i16.VisitorBuildingUnits) {
      return _i16.VisitorBuildingUnits.fromJson(data, this) as T;
    }
    if (t == _i17.VisitorCompanies) {
      return _i17.VisitorCompanies.fromJson(data, this) as T;
    }
    if (t == _i18.VisitorCompanyBuildings) {
      return _i18.VisitorCompanyBuildings.fromJson(data, this) as T;
    }
    if (t == _i19.Visitors) {
      return _i19.Visitors.fromJson(data, this) as T;
    }
    if (t == _i1.getType<_i3.DeliveryVisitors?>()) {
      return (data != null ? _i3.DeliveryVisitors.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i4.Example?>()) {
      return (data != null ? _i4.Example.fromJson(data, this) : null) as T;
    }
    if (t == _i1.getType<_i5.GuestVisitors?>()) {
      return (data != null ? _i5.GuestVisitors.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i6.MemberCategories?>()) {
      return (data != null ? _i6.MemberCategories.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i7.MemberStaff?>()) {
      return (data != null ? _i7.MemberStaff.fromJson(data, this) : null) as T;
    }
    if (t == _i1.getType<_i8.MemberSubCategories?>()) {
      return (data != null
          ? _i8.MemberSubCategories.fromJson(data, this)
          : null) as T;
    }
    if (t == _i1.getType<_i9.StaffBuildingUnits?>()) {
      return (data != null ? _i9.StaffBuildingUnits.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i10.StaffCompanies?>()) {
      return (data != null ? _i10.StaffCompanies.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i11.StaffCompanyBuilding?>()) {
      return (data != null
          ? _i11.StaffCompanyBuilding.fromJson(data, this)
          : null) as T;
    }
    if (t == _i1.getType<_i12.StaffVisitors?>()) {
      return (data != null ? _i12.StaffVisitors.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i13.TransportVisitors?>()) {
      return (data != null ? _i13.TransportVisitors.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i14.VendorVisitors?>()) {
      return (data != null ? _i14.VendorVisitors.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i15.VerificationTypes?>()) {
      return (data != null ? _i15.VerificationTypes.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i16.VisitorBuildingUnits?>()) {
      return (data != null
          ? _i16.VisitorBuildingUnits.fromJson(data, this)
          : null) as T;
    }
    if (t == _i1.getType<_i17.VisitorCompanies?>()) {
      return (data != null ? _i17.VisitorCompanies.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i18.VisitorCompanyBuildings?>()) {
      return (data != null
          ? _i18.VisitorCompanyBuildings.fromJson(data, this)
          : null) as T;
    }
    if (t == _i1.getType<_i19.Visitors?>()) {
      return (data != null ? _i19.Visitors.fromJson(data, this) : null) as T;
    }
    try {
      return _i2.Protocol().deserialize<T>(data, t);
    } catch (_) {}
    return super.deserialize<T>(data, t);
  }

  @override
  String? getClassNameForObject(Object data) {
    if (data is _i3.DeliveryVisitors) {
      return 'DeliveryVisitors';
    }
    if (data is _i4.Example) {
      return 'Example';
    }
    if (data is _i5.GuestVisitors) {
      return 'GuestVisitors';
    }
    if (data is _i6.MemberCategories) {
      return 'MemberCategories';
    }
    if (data is _i7.MemberStaff) {
      return 'MemberStaff';
    }
    if (data is _i8.MemberSubCategories) {
      return 'MemberSubCategories';
    }
    if (data is _i9.StaffBuildingUnits) {
      return 'StaffBuildingUnits';
    }
    if (data is _i10.StaffCompanies) {
      return 'StaffCompanies';
    }
    if (data is _i11.StaffCompanyBuilding) {
      return 'StaffCompanyBuilding';
    }
    if (data is _i12.StaffVisitors) {
      return 'StaffVisitors';
    }
    if (data is _i13.TransportVisitors) {
      return 'TransportVisitors';
    }
    if (data is _i14.VendorVisitors) {
      return 'VendorVisitors';
    }
    if (data is _i15.VerificationTypes) {
      return 'VerificationTypes';
    }
    if (data is _i16.VisitorBuildingUnits) {
      return 'VisitorBuildingUnits';
    }
    if (data is _i17.VisitorCompanies) {
      return 'VisitorCompanies';
    }
    if (data is _i18.VisitorCompanyBuildings) {
      return 'VisitorCompanyBuildings';
    }
    if (data is _i19.Visitors) {
      return 'Visitors';
    }
    return super.getClassNameForObject(data);
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    if (data['className'] == 'DeliveryVisitors') {
      return deserialize<_i3.DeliveryVisitors>(data['data']);
    }
    if (data['className'] == 'Example') {
      return deserialize<_i4.Example>(data['data']);
    }
    if (data['className'] == 'GuestVisitors') {
      return deserialize<_i5.GuestVisitors>(data['data']);
    }
    if (data['className'] == 'MemberCategories') {
      return deserialize<_i6.MemberCategories>(data['data']);
    }
    if (data['className'] == 'MemberStaff') {
      return deserialize<_i7.MemberStaff>(data['data']);
    }
    if (data['className'] == 'MemberSubCategories') {
      return deserialize<_i8.MemberSubCategories>(data['data']);
    }
    if (data['className'] == 'StaffBuildingUnits') {
      return deserialize<_i9.StaffBuildingUnits>(data['data']);
    }
    if (data['className'] == 'StaffCompanies') {
      return deserialize<_i10.StaffCompanies>(data['data']);
    }
    if (data['className'] == 'StaffCompanyBuilding') {
      return deserialize<_i11.StaffCompanyBuilding>(data['data']);
    }
    if (data['className'] == 'StaffVisitors') {
      return deserialize<_i12.StaffVisitors>(data['data']);
    }
    if (data['className'] == 'TransportVisitors') {
      return deserialize<_i13.TransportVisitors>(data['data']);
    }
    if (data['className'] == 'VendorVisitors') {
      return deserialize<_i14.VendorVisitors>(data['data']);
    }
    if (data['className'] == 'VerificationTypes') {
      return deserialize<_i15.VerificationTypes>(data['data']);
    }
    if (data['className'] == 'VisitorBuildingUnits') {
      return deserialize<_i16.VisitorBuildingUnits>(data['data']);
    }
    if (data['className'] == 'VisitorCompanies') {
      return deserialize<_i17.VisitorCompanies>(data['data']);
    }
    if (data['className'] == 'VisitorCompanyBuildings') {
      return deserialize<_i18.VisitorCompanyBuildings>(data['data']);
    }
    if (data['className'] == 'Visitors') {
      return deserialize<_i19.Visitors>(data['data']);
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
      case _i3.DeliveryVisitors:
        return _i3.DeliveryVisitors.t;
      case _i5.GuestVisitors:
        return _i5.GuestVisitors.t;
      case _i6.MemberCategories:
        return _i6.MemberCategories.t;
      case _i7.MemberStaff:
        return _i7.MemberStaff.t;
      case _i8.MemberSubCategories:
        return _i8.MemberSubCategories.t;
      case _i9.StaffBuildingUnits:
        return _i9.StaffBuildingUnits.t;
      case _i10.StaffCompanies:
        return _i10.StaffCompanies.t;
      case _i11.StaffCompanyBuilding:
        return _i11.StaffCompanyBuilding.t;
      case _i12.StaffVisitors:
        return _i12.StaffVisitors.t;
      case _i13.TransportVisitors:
        return _i13.TransportVisitors.t;
      case _i14.VendorVisitors:
        return _i14.VendorVisitors.t;
      case _i15.VerificationTypes:
        return _i15.VerificationTypes.t;
      case _i16.VisitorBuildingUnits:
        return _i16.VisitorBuildingUnits.t;
      case _i17.VisitorCompanies:
        return _i17.VisitorCompanies.t;
      case _i18.VisitorCompanyBuildings:
        return _i18.VisitorCompanyBuildings.t;
      case _i19.Visitors:
        return _i19.Visitors.t;
    }
    return null;
  }

  @override
  _i2.DatabaseDefinition getTargetDatabaseDefinition() =>
      targetDatabaseDefinition;
}
