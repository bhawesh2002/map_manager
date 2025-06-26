// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'map_mode.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$MapMode {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(bool trackUserLoc) basic,
    required TResult Function(int maxSelections, List<Point>? preSelectedLocs)
        locationSel,
    required TResult Function(LineString? route, Map<String, dynamic>? geojson)
        route,
    required TResult Function(Map<String, dynamic> geojson,
            List<Point>? waypoints, RouteTraversalSource source)
        tracking,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(bool trackUserLoc)? basic,
    TResult? Function(int maxSelections, List<Point>? preSelectedLocs)?
        locationSel,
    TResult? Function(LineString? route, Map<String, dynamic>? geojson)? route,
    TResult? Function(Map<String, dynamic> geojson, List<Point>? waypoints,
            RouteTraversalSource source)?
        tracking,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(bool trackUserLoc)? basic,
    TResult Function(int maxSelections, List<Point>? preSelectedLocs)?
        locationSel,
    TResult Function(LineString? route, Map<String, dynamic>? geojson)? route,
    TResult Function(Map<String, dynamic> geojson, List<Point>? waypoints,
            RouteTraversalSource source)?
        tracking,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(BasicMapMode value) basic,
    required TResult Function(LocationSelectionMode value) locationSel,
    required TResult Function(RouteMode value) route,
    required TResult Function(TrackingMode value) tracking,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BasicMapMode value)? basic,
    TResult? Function(LocationSelectionMode value)? locationSel,
    TResult? Function(RouteMode value)? route,
    TResult? Function(TrackingMode value)? tracking,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BasicMapMode value)? basic,
    TResult Function(LocationSelectionMode value)? locationSel,
    TResult Function(RouteMode value)? route,
    TResult Function(TrackingMode value)? tracking,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MapModeCopyWith<$Res> {
  factory $MapModeCopyWith(MapMode value, $Res Function(MapMode) then) =
      _$MapModeCopyWithImpl<$Res, MapMode>;
}

/// @nodoc
class _$MapModeCopyWithImpl<$Res, $Val extends MapMode>
    implements $MapModeCopyWith<$Res> {
  _$MapModeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MapMode
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$BasicMapModeImplCopyWith<$Res> {
  factory _$$BasicMapModeImplCopyWith(
          _$BasicMapModeImpl value, $Res Function(_$BasicMapModeImpl) then) =
      __$$BasicMapModeImplCopyWithImpl<$Res>;
  @useResult
  $Res call({bool trackUserLoc});
}

/// @nodoc
class __$$BasicMapModeImplCopyWithImpl<$Res>
    extends _$MapModeCopyWithImpl<$Res, _$BasicMapModeImpl>
    implements _$$BasicMapModeImplCopyWith<$Res> {
  __$$BasicMapModeImplCopyWithImpl(
      _$BasicMapModeImpl _value, $Res Function(_$BasicMapModeImpl) _then)
      : super(_value, _then);

  /// Create a copy of MapMode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? trackUserLoc = null,
  }) {
    return _then(_$BasicMapModeImpl(
      trackUserLoc: null == trackUserLoc
          ? _value.trackUserLoc
          : trackUserLoc // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$BasicMapModeImpl extends BasicMapMode {
  _$BasicMapModeImpl({this.trackUserLoc = true}) : super._();

  @override
  @JsonKey()
  final bool trackUserLoc;

  @override
  String toString() {
    return 'MapMode.basic(trackUserLoc: $trackUserLoc)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BasicMapModeImpl &&
            (identical(other.trackUserLoc, trackUserLoc) ||
                other.trackUserLoc == trackUserLoc));
  }

  @override
  int get hashCode => Object.hash(runtimeType, trackUserLoc);

  /// Create a copy of MapMode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BasicMapModeImplCopyWith<_$BasicMapModeImpl> get copyWith =>
      __$$BasicMapModeImplCopyWithImpl<_$BasicMapModeImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(bool trackUserLoc) basic,
    required TResult Function(int maxSelections, List<Point>? preSelectedLocs)
        locationSel,
    required TResult Function(LineString? route, Map<String, dynamic>? geojson)
        route,
    required TResult Function(Map<String, dynamic> geojson,
            List<Point>? waypoints, RouteTraversalSource source)
        tracking,
  }) {
    return basic(trackUserLoc);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(bool trackUserLoc)? basic,
    TResult? Function(int maxSelections, List<Point>? preSelectedLocs)?
        locationSel,
    TResult? Function(LineString? route, Map<String, dynamic>? geojson)? route,
    TResult? Function(Map<String, dynamic> geojson, List<Point>? waypoints,
            RouteTraversalSource source)?
        tracking,
  }) {
    return basic?.call(trackUserLoc);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(bool trackUserLoc)? basic,
    TResult Function(int maxSelections, List<Point>? preSelectedLocs)?
        locationSel,
    TResult Function(LineString? route, Map<String, dynamic>? geojson)? route,
    TResult Function(Map<String, dynamic> geojson, List<Point>? waypoints,
            RouteTraversalSource source)?
        tracking,
    required TResult orElse(),
  }) {
    if (basic != null) {
      return basic(trackUserLoc);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(BasicMapMode value) basic,
    required TResult Function(LocationSelectionMode value) locationSel,
    required TResult Function(RouteMode value) route,
    required TResult Function(TrackingMode value) tracking,
  }) {
    return basic(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BasicMapMode value)? basic,
    TResult? Function(LocationSelectionMode value)? locationSel,
    TResult? Function(RouteMode value)? route,
    TResult? Function(TrackingMode value)? tracking,
  }) {
    return basic?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BasicMapMode value)? basic,
    TResult Function(LocationSelectionMode value)? locationSel,
    TResult Function(RouteMode value)? route,
    TResult Function(TrackingMode value)? tracking,
    required TResult orElse(),
  }) {
    if (basic != null) {
      return basic(this);
    }
    return orElse();
  }
}

abstract class BasicMapMode extends MapMode {
  factory BasicMapMode({final bool trackUserLoc}) = _$BasicMapModeImpl;
  BasicMapMode._() : super._();

  bool get trackUserLoc;

  /// Create a copy of MapMode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BasicMapModeImplCopyWith<_$BasicMapModeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$LocationSelectionModeImplCopyWith<$Res> {
  factory _$$LocationSelectionModeImplCopyWith(
          _$LocationSelectionModeImpl value,
          $Res Function(_$LocationSelectionModeImpl) then) =
      __$$LocationSelectionModeImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int maxSelections, List<Point>? preSelectedLocs});
}

/// @nodoc
class __$$LocationSelectionModeImplCopyWithImpl<$Res>
    extends _$MapModeCopyWithImpl<$Res, _$LocationSelectionModeImpl>
    implements _$$LocationSelectionModeImplCopyWith<$Res> {
  __$$LocationSelectionModeImplCopyWithImpl(_$LocationSelectionModeImpl _value,
      $Res Function(_$LocationSelectionModeImpl) _then)
      : super(_value, _then);

  /// Create a copy of MapMode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? maxSelections = null,
    Object? preSelectedLocs = freezed,
  }) {
    return _then(_$LocationSelectionModeImpl(
      maxSelections: null == maxSelections
          ? _value.maxSelections
          : maxSelections // ignore: cast_nullable_to_non_nullable
              as int,
      preSelectedLocs: freezed == preSelectedLocs
          ? _value._preSelectedLocs
          : preSelectedLocs // ignore: cast_nullable_to_non_nullable
              as List<Point>?,
    ));
  }
}

/// @nodoc

class _$LocationSelectionModeImpl extends LocationSelectionMode {
  _$LocationSelectionModeImpl(
      {this.maxSelections = 1, final List<Point>? preSelectedLocs = const []})
      : assert((preSelectedLocs?.length ?? 0) <= maxSelections,
            'pre selection loctations must not exceed maxSelections'),
        _preSelectedLocs = preSelectedLocs,
        super._();

  @override
  @JsonKey()
  final int maxSelections;
  final List<Point>? _preSelectedLocs;
  @override
  @JsonKey()
  List<Point>? get preSelectedLocs {
    final value = _preSelectedLocs;
    if (value == null) return null;
    if (_preSelectedLocs is EqualUnmodifiableListView) return _preSelectedLocs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'MapMode.locationSel(maxSelections: $maxSelections, preSelectedLocs: $preSelectedLocs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LocationSelectionModeImpl &&
            (identical(other.maxSelections, maxSelections) ||
                other.maxSelections == maxSelections) &&
            const DeepCollectionEquality()
                .equals(other._preSelectedLocs, _preSelectedLocs));
  }

  @override
  int get hashCode => Object.hash(runtimeType, maxSelections,
      const DeepCollectionEquality().hash(_preSelectedLocs));

  /// Create a copy of MapMode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LocationSelectionModeImplCopyWith<_$LocationSelectionModeImpl>
      get copyWith => __$$LocationSelectionModeImplCopyWithImpl<
          _$LocationSelectionModeImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(bool trackUserLoc) basic,
    required TResult Function(int maxSelections, List<Point>? preSelectedLocs)
        locationSel,
    required TResult Function(LineString? route, Map<String, dynamic>? geojson)
        route,
    required TResult Function(Map<String, dynamic> geojson,
            List<Point>? waypoints, RouteTraversalSource source)
        tracking,
  }) {
    return locationSel(maxSelections, preSelectedLocs);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(bool trackUserLoc)? basic,
    TResult? Function(int maxSelections, List<Point>? preSelectedLocs)?
        locationSel,
    TResult? Function(LineString? route, Map<String, dynamic>? geojson)? route,
    TResult? Function(Map<String, dynamic> geojson, List<Point>? waypoints,
            RouteTraversalSource source)?
        tracking,
  }) {
    return locationSel?.call(maxSelections, preSelectedLocs);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(bool trackUserLoc)? basic,
    TResult Function(int maxSelections, List<Point>? preSelectedLocs)?
        locationSel,
    TResult Function(LineString? route, Map<String, dynamic>? geojson)? route,
    TResult Function(Map<String, dynamic> geojson, List<Point>? waypoints,
            RouteTraversalSource source)?
        tracking,
    required TResult orElse(),
  }) {
    if (locationSel != null) {
      return locationSel(maxSelections, preSelectedLocs);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(BasicMapMode value) basic,
    required TResult Function(LocationSelectionMode value) locationSel,
    required TResult Function(RouteMode value) route,
    required TResult Function(TrackingMode value) tracking,
  }) {
    return locationSel(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BasicMapMode value)? basic,
    TResult? Function(LocationSelectionMode value)? locationSel,
    TResult? Function(RouteMode value)? route,
    TResult? Function(TrackingMode value)? tracking,
  }) {
    return locationSel?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BasicMapMode value)? basic,
    TResult Function(LocationSelectionMode value)? locationSel,
    TResult Function(RouteMode value)? route,
    TResult Function(TrackingMode value)? tracking,
    required TResult orElse(),
  }) {
    if (locationSel != null) {
      return locationSel(this);
    }
    return orElse();
  }
}

abstract class LocationSelectionMode extends MapMode {
  factory LocationSelectionMode(
      {final int maxSelections,
      final List<Point>? preSelectedLocs}) = _$LocationSelectionModeImpl;
  LocationSelectionMode._() : super._();

  int get maxSelections;
  List<Point>? get preSelectedLocs;

  /// Create a copy of MapMode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LocationSelectionModeImplCopyWith<_$LocationSelectionModeImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RouteModeImplCopyWith<$Res> {
  factory _$$RouteModeImplCopyWith(
          _$RouteModeImpl value, $Res Function(_$RouteModeImpl) then) =
      __$$RouteModeImplCopyWithImpl<$Res>;
  @useResult
  $Res call({LineString? route, Map<String, dynamic>? geojson});
}

/// @nodoc
class __$$RouteModeImplCopyWithImpl<$Res>
    extends _$MapModeCopyWithImpl<$Res, _$RouteModeImpl>
    implements _$$RouteModeImplCopyWith<$Res> {
  __$$RouteModeImplCopyWithImpl(
      _$RouteModeImpl _value, $Res Function(_$RouteModeImpl) _then)
      : super(_value, _then);

  /// Create a copy of MapMode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? route = freezed,
    Object? geojson = freezed,
  }) {
    return _then(_$RouteModeImpl(
      route: freezed == route
          ? _value.route
          : route // ignore: cast_nullable_to_non_nullable
              as LineString?,
      geojson: freezed == geojson
          ? _value._geojson
          : geojson // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc

class _$RouteModeImpl extends RouteMode {
  _$RouteModeImpl({this.route, final Map<String, dynamic>? geojson})
      : assert(!(route != null && geojson != null),
            'Both route and geojson cannot be provided'),
        _geojson = geojson,
        super._();

  @override
  final LineString? route;
  final Map<String, dynamic>? _geojson;
  @override
  Map<String, dynamic>? get geojson {
    final value = _geojson;
    if (value == null) return null;
    if (_geojson is EqualUnmodifiableMapView) return _geojson;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'MapMode.route(route: $route, geojson: $geojson)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RouteModeImpl &&
            (identical(other.route, route) || other.route == route) &&
            const DeepCollectionEquality().equals(other._geojson, _geojson));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, route, const DeepCollectionEquality().hash(_geojson));

  /// Create a copy of MapMode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RouteModeImplCopyWith<_$RouteModeImpl> get copyWith =>
      __$$RouteModeImplCopyWithImpl<_$RouteModeImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(bool trackUserLoc) basic,
    required TResult Function(int maxSelections, List<Point>? preSelectedLocs)
        locationSel,
    required TResult Function(LineString? route, Map<String, dynamic>? geojson)
        route,
    required TResult Function(Map<String, dynamic> geojson,
            List<Point>? waypoints, RouteTraversalSource source)
        tracking,
  }) {
    return route(this.route, geojson);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(bool trackUserLoc)? basic,
    TResult? Function(int maxSelections, List<Point>? preSelectedLocs)?
        locationSel,
    TResult? Function(LineString? route, Map<String, dynamic>? geojson)? route,
    TResult? Function(Map<String, dynamic> geojson, List<Point>? waypoints,
            RouteTraversalSource source)?
        tracking,
  }) {
    return route?.call(this.route, geojson);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(bool trackUserLoc)? basic,
    TResult Function(int maxSelections, List<Point>? preSelectedLocs)?
        locationSel,
    TResult Function(LineString? route, Map<String, dynamic>? geojson)? route,
    TResult Function(Map<String, dynamic> geojson, List<Point>? waypoints,
            RouteTraversalSource source)?
        tracking,
    required TResult orElse(),
  }) {
    if (route != null) {
      return route(this.route, geojson);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(BasicMapMode value) basic,
    required TResult Function(LocationSelectionMode value) locationSel,
    required TResult Function(RouteMode value) route,
    required TResult Function(TrackingMode value) tracking,
  }) {
    return route(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BasicMapMode value)? basic,
    TResult? Function(LocationSelectionMode value)? locationSel,
    TResult? Function(RouteMode value)? route,
    TResult? Function(TrackingMode value)? tracking,
  }) {
    return route?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BasicMapMode value)? basic,
    TResult Function(LocationSelectionMode value)? locationSel,
    TResult Function(RouteMode value)? route,
    TResult Function(TrackingMode value)? tracking,
    required TResult orElse(),
  }) {
    if (route != null) {
      return route(this);
    }
    return orElse();
  }
}

abstract class RouteMode extends MapMode {
  factory RouteMode(
      {final LineString? route,
      final Map<String, dynamic>? geojson}) = _$RouteModeImpl;
  RouteMode._() : super._();

  LineString? get route;
  Map<String, dynamic>? get geojson;

  /// Create a copy of MapMode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RouteModeImplCopyWith<_$RouteModeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$TrackingModeImplCopyWith<$Res> {
  factory _$$TrackingModeImplCopyWith(
          _$TrackingModeImpl value, $Res Function(_$TrackingModeImpl) then) =
      __$$TrackingModeImplCopyWithImpl<$Res>;
  @useResult
  $Res call(
      {Map<String, dynamic> geojson,
      List<Point>? waypoints,
      RouteTraversalSource source});
}

/// @nodoc
class __$$TrackingModeImplCopyWithImpl<$Res>
    extends _$MapModeCopyWithImpl<$Res, _$TrackingModeImpl>
    implements _$$TrackingModeImplCopyWith<$Res> {
  __$$TrackingModeImplCopyWithImpl(
      _$TrackingModeImpl _value, $Res Function(_$TrackingModeImpl) _then)
      : super(_value, _then);

  /// Create a copy of MapMode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? geojson = null,
    Object? waypoints = freezed,
    Object? source = null,
  }) {
    return _then(_$TrackingModeImpl(
      geojson: null == geojson
          ? _value._geojson
          : geojson // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      waypoints: freezed == waypoints
          ? _value._waypoints
          : waypoints // ignore: cast_nullable_to_non_nullable
              as List<Point>?,
      source: null == source
          ? _value.source
          : source // ignore: cast_nullable_to_non_nullable
              as RouteTraversalSource,
    ));
  }
}

/// @nodoc

class _$TrackingModeImpl extends TrackingMode {
  _$TrackingModeImpl(
      {required final Map<String, dynamic> geojson,
      final List<Point>? waypoints,
      this.source = RouteTraversalSource.user})
      : _geojson = geojson,
        _waypoints = waypoints,
        super._();

  final Map<String, dynamic> _geojson;
  @override
  Map<String, dynamic> get geojson {
    if (_geojson is EqualUnmodifiableMapView) return _geojson;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_geojson);
  }

  final List<Point>? _waypoints;
  @override
  List<Point>? get waypoints {
    final value = _waypoints;
    if (value == null) return null;
    if (_waypoints is EqualUnmodifiableListView) return _waypoints;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey()
  final RouteTraversalSource source;

  @override
  String toString() {
    return 'MapMode.tracking(geojson: $geojson, waypoints: $waypoints, source: $source)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TrackingModeImpl &&
            const DeepCollectionEquality().equals(other._geojson, _geojson) &&
            const DeepCollectionEquality()
                .equals(other._waypoints, _waypoints) &&
            (identical(other.source, source) || other.source == source));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_geojson),
      const DeepCollectionEquality().hash(_waypoints),
      source);

  /// Create a copy of MapMode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TrackingModeImplCopyWith<_$TrackingModeImpl> get copyWith =>
      __$$TrackingModeImplCopyWithImpl<_$TrackingModeImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(bool trackUserLoc) basic,
    required TResult Function(int maxSelections, List<Point>? preSelectedLocs)
        locationSel,
    required TResult Function(LineString? route, Map<String, dynamic>? geojson)
        route,
    required TResult Function(Map<String, dynamic> geojson,
            List<Point>? waypoints, RouteTraversalSource source)
        tracking,
  }) {
    return tracking(geojson, waypoints, source);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(bool trackUserLoc)? basic,
    TResult? Function(int maxSelections, List<Point>? preSelectedLocs)?
        locationSel,
    TResult? Function(LineString? route, Map<String, dynamic>? geojson)? route,
    TResult? Function(Map<String, dynamic> geojson, List<Point>? waypoints,
            RouteTraversalSource source)?
        tracking,
  }) {
    return tracking?.call(geojson, waypoints, source);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(bool trackUserLoc)? basic,
    TResult Function(int maxSelections, List<Point>? preSelectedLocs)?
        locationSel,
    TResult Function(LineString? route, Map<String, dynamic>? geojson)? route,
    TResult Function(Map<String, dynamic> geojson, List<Point>? waypoints,
            RouteTraversalSource source)?
        tracking,
    required TResult orElse(),
  }) {
    if (tracking != null) {
      return tracking(geojson, waypoints, source);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(BasicMapMode value) basic,
    required TResult Function(LocationSelectionMode value) locationSel,
    required TResult Function(RouteMode value) route,
    required TResult Function(TrackingMode value) tracking,
  }) {
    return tracking(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BasicMapMode value)? basic,
    TResult? Function(LocationSelectionMode value)? locationSel,
    TResult? Function(RouteMode value)? route,
    TResult? Function(TrackingMode value)? tracking,
  }) {
    return tracking?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BasicMapMode value)? basic,
    TResult Function(LocationSelectionMode value)? locationSel,
    TResult Function(RouteMode value)? route,
    TResult Function(TrackingMode value)? tracking,
    required TResult orElse(),
  }) {
    if (tracking != null) {
      return tracking(this);
    }
    return orElse();
  }
}

abstract class TrackingMode extends MapMode {
  factory TrackingMode(
      {required final Map<String, dynamic> geojson,
      final List<Point>? waypoints,
      final RouteTraversalSource source}) = _$TrackingModeImpl;
  TrackingMode._() : super._();

  Map<String, dynamic> get geojson;
  List<Point>? get waypoints;
  RouteTraversalSource get source;

  /// Create a copy of MapMode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TrackingModeImplCopyWith<_$TrackingModeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
