// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_tokens.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AuthTokens _$AuthTokensFromJson(Map<String, dynamic> json) {
  return _AuthTokens.fromJson(json);
}

/// @nodoc
mixin _$AuthTokens {
  String get accessToken => throw _privateConstructorUsedError;
  String get refreshToken => throw _privateConstructorUsedError;
  DateTime get expiresAt => throw _privateConstructorUsedError;
  String get idToken => throw _privateConstructorUsedError;
  bool get isExpired => throw _privateConstructorUsedError;

  /// Serializes this AuthTokens to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AuthTokens
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AuthTokensCopyWith<AuthTokens> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AuthTokensCopyWith<$Res> {
  factory $AuthTokensCopyWith(
          AuthTokens value, $Res Function(AuthTokens) then) =
      _$AuthTokensCopyWithImpl<$Res, AuthTokens>;
  @useResult
  $Res call(
      {String accessToken,
      String refreshToken,
      DateTime expiresAt,
      String idToken,
      bool isExpired});
}

/// @nodoc
class _$AuthTokensCopyWithImpl<$Res, $Val extends AuthTokens>
    implements $AuthTokensCopyWith<$Res> {
  _$AuthTokensCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AuthTokens
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? accessToken = null,
    Object? refreshToken = null,
    Object? expiresAt = null,
    Object? idToken = null,
    Object? isExpired = null,
  }) {
    return _then(_value.copyWith(
      accessToken: null == accessToken
          ? _value.accessToken
          : accessToken // ignore: cast_nullable_to_non_nullable
              as String,
      refreshToken: null == refreshToken
          ? _value.refreshToken
          : refreshToken // ignore: cast_nullable_to_non_nullable
              as String,
      expiresAt: null == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      idToken: null == idToken
          ? _value.idToken
          : idToken // ignore: cast_nullable_to_non_nullable
              as String,
      isExpired: null == isExpired
          ? _value.isExpired
          : isExpired // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AuthTokensImplCopyWith<$Res>
    implements $AuthTokensCopyWith<$Res> {
  factory _$$AuthTokensImplCopyWith(
          _$AuthTokensImpl value, $Res Function(_$AuthTokensImpl) then) =
      __$$AuthTokensImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String accessToken,
      String refreshToken,
      DateTime expiresAt,
      String idToken,
      bool isExpired});
}

/// @nodoc
class __$$AuthTokensImplCopyWithImpl<$Res>
    extends _$AuthTokensCopyWithImpl<$Res, _$AuthTokensImpl>
    implements _$$AuthTokensImplCopyWith<$Res> {
  __$$AuthTokensImplCopyWithImpl(
      _$AuthTokensImpl _value, $Res Function(_$AuthTokensImpl) _then)
      : super(_value, _then);

  /// Create a copy of AuthTokens
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? accessToken = null,
    Object? refreshToken = null,
    Object? expiresAt = null,
    Object? idToken = null,
    Object? isExpired = null,
  }) {
    return _then(_$AuthTokensImpl(
      accessToken: null == accessToken
          ? _value.accessToken
          : accessToken // ignore: cast_nullable_to_non_nullable
              as String,
      refreshToken: null == refreshToken
          ? _value.refreshToken
          : refreshToken // ignore: cast_nullable_to_non_nullable
              as String,
      expiresAt: null == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      idToken: null == idToken
          ? _value.idToken
          : idToken // ignore: cast_nullable_to_non_nullable
              as String,
      isExpired: null == isExpired
          ? _value.isExpired
          : isExpired // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AuthTokensImpl implements _AuthTokens {
  const _$AuthTokensImpl(
      {required this.accessToken,
      required this.refreshToken,
      required this.expiresAt,
      required this.idToken,
      this.isExpired = false});

  factory _$AuthTokensImpl.fromJson(Map<String, dynamic> json) =>
      _$$AuthTokensImplFromJson(json);

  @override
  final String accessToken;
  @override
  final String refreshToken;
  @override
  final DateTime expiresAt;
  @override
  final String idToken;
  @override
  @JsonKey()
  final bool isExpired;

  @override
  String toString() {
    return 'AuthTokens(accessToken: $accessToken, refreshToken: $refreshToken, expiresAt: $expiresAt, idToken: $idToken, isExpired: $isExpired)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AuthTokensImpl &&
            (identical(other.accessToken, accessToken) ||
                other.accessToken == accessToken) &&
            (identical(other.refreshToken, refreshToken) ||
                other.refreshToken == refreshToken) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.idToken, idToken) || other.idToken == idToken) &&
            (identical(other.isExpired, isExpired) ||
                other.isExpired == isExpired));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, accessToken, refreshToken, expiresAt, idToken, isExpired);

  /// Create a copy of AuthTokens
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AuthTokensImplCopyWith<_$AuthTokensImpl> get copyWith =>
      __$$AuthTokensImplCopyWithImpl<_$AuthTokensImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AuthTokensImplToJson(
      this,
    );
  }
}

abstract class _AuthTokens implements AuthTokens {
  const factory _AuthTokens(
      {required final String accessToken,
      required final String refreshToken,
      required final DateTime expiresAt,
      required final String idToken,
      final bool isExpired}) = _$AuthTokensImpl;

  factory _AuthTokens.fromJson(Map<String, dynamic> json) =
      _$AuthTokensImpl.fromJson;

  @override
  String get accessToken;
  @override
  String get refreshToken;
  @override
  DateTime get expiresAt;
  @override
  String get idToken;
  @override
  bool get isExpired;

  /// Create a copy of AuthTokens
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AuthTokensImplCopyWith<_$AuthTokensImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
