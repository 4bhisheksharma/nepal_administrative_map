import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../data/loader/map_data_source.dart';
import '../data/loader/nepal_map_data.dart';
import '../data/models/region.dart';
import '../i18n/map_language.dart';
import '../i18n/nepal_map_strings.dart';
import '../rendering/asset_map_data_source.dart';
import '../rendering/geometry_cache.dart';
import '../rendering/layers/border_layer.dart';
import '../rendering/layers/highlight_layer.dart';
import '../rendering/layers/label_layer.dart';
import '../rendering/layers/marker_dot_layer.dart';
import '../rendering/layers/protected_area_layer.dart';
import '../rendering/layers/region_fill_layer.dart';
import '../rendering/map_camera.dart';
import '../rendering/map_layer.dart';
import '../rendering/map_plane.dart';
import '../rendering/region_semantics.dart';
import '../rendering/style/nepal_map_theme.dart';
import '../rendering/style/region_style.dart';
import 'choropleth.dart';
import 'map_marker.dart';
import 'nepal_map_controller.dart';
import 'nepal_map_legend.dart';
import 'region_tooltip.dart';

/// How tapping regions changes the selection.
enum SelectionMode {
  /// Taps don't select (`onRegionTap` still fires).
  none,

  /// At most one region is selected; tapping it again deselects it.
  single,

  /// Taps toggle regions in and out of the selection.
  multi,
}

/// Which names region labels show.
enum LabelMode {
  /// No labels.
  none,

  /// English names.
  en,

  /// Nepali names.
  ne,

  /// English with Nepali underneath.
  both;

  /// The label text for [region] in this mode, or `null` for [none].
  String? textOf(Region region) {
    final name = region.name;
    return switch (this) {
      none => null,
      en => name.en,
      ne => name.ne,
      both => name.en == name.ne ? name.en : '${name.en}\n${name.ne}',
    };
  }
}

/// Builds a region's label text. Return `null` to hide its label.
typedef RegionLabelBuilder = String? Function(
  Region region,
  MapLanguage language,
);

/// An interactive map of Nepal's provinces, districts or local levels.
///
/// ```dart
/// NepalMap(
///   level: AdminLevel.district,
///   scope: Province.gandaki,
///   onRegionTap: (region) => print(region.name.en),
/// )
/// ```
///
/// Every parameter is optional; `NepalMap()` shows the 7 provinces. Pinch,
/// drag, double-tap and the mouse wheel zoom and pan; hovering shows a
/// tooltip. Use a [NepalMapController] to drive it from code.
class NepalMap extends StatefulWidget {
  /// Creates a map.
  const NepalMap({
    super.key,
    this.controller,
    this.level = AdminLevel.province,
    this.scope,
    this.drillDown = false,
    this.onScopeChanged,
    this.style,
    this.onRegionTap,
    this.onRegionHover,
    this.selectionMode = SelectionMode.single,
    this.selected,
    this.onSelectionChanged,
    this.language,
    this.strings,
    this.labelMode,
    this.labelBuilder,
    this.showTooltips = true,
    this.tooltipBuilder,
    this.interactive = true,
    this.minZoom = 1,
    this.maxZoom = 40,
    this.animationDuration = const Duration(milliseconds: 400),
    this.animationCurve = Curves.easeInOutCubic,
    this.theme,
    this.padding = const EdgeInsets.all(8),
    this.placeholder,
    this.errorBuilder,
    this.showAttribution = true,
    this.onAttributionTap,
    this.dataSource = const AssetMapDataSource(),
    this.choropleth,
    this.markers = const [],
    this.onMarkerTap,
    this.showProtectedAreas = false,
    this.extraLayers = const [],
  });

  /// Credit line for the boundary data, required by its CC BY 4.0 license.
  static const String attribution =
      'Boundary data © OKNP LocalBoundaries, CC BY 4.0';

  /// Link to the data license.
  static const String attributionUrl =
      'https://creativecommons.org/licenses/by/4.0/';

  /// Loads the bundled map data ahead of time, e.g. during a splash screen,
  /// so the first map appears without a loading state.
  ///
  /// The result also answers point lookups without a map on screen:
  /// `(await NepalMap.preload()).localLevelAt(point)`.
  static Future<NepalMapData> preload({
    MapDataSource source = const AssetMapDataSource(),
  }) => NepalMapData.load(source);

  /// Drives the map from code: selection, zoom, drill-down, language.
  final NepalMapController? controller;

  /// Which regions to draw (the starting level when [drillDown] is on).
  final AdminLevel level;

  /// Only show regions inside this province or district, zoomed to fit it.
  /// Must be a coarser level than [level].
  final Region? scope;

  /// Whether tapping a province shows its districts, and tapping a district
  /// its local levels. Taps select only at the local level. Go back with
  /// [NepalMapController.drillUp], a [NepalMapBreadcrumb], or Esc.
  final bool drillDown;

  /// Called after drilling down or up, with the new scope (`null` for all
  /// of Nepal).
  final ValueChanged<Region?>? onScopeChanged;

  /// How each region is drawn. Defaults to [NepalMapTheme.defaultStyle].
  final RegionStyleBuilder? style;

  /// Called when a region is tapped.
  final ValueChanged<Region>? onRegionTap;

  /// Called when the mouse moves onto a region, or off all regions (`null`).
  final ValueChanged<Region?>? onRegionHover;

  /// How taps change the selection.
  final SelectionMode selectionMode;

  /// The selected regions, if you manage the selection yourself. When
  /// `null`, the selection lives in the [controller] (or the map).
  final Set<Region>? selected;

  /// Called with the new selection after a tap changes it.
  final ValueChanged<Set<Region>>? onSelectionChanged;

  /// The language for names and text. [NepalMapController.language] takes
  /// precedence; otherwise defaults to the app's locale: Nepali for `ne`,
  /// English otherwise.
  final MapLanguage? language;

  /// Replaces the built-in UI strings, whatever the [language].
  final NepalMapStrings? strings;

  /// Which names labels show. Defaults to the active language; use
  /// [LabelMode.none] to hide labels.
  final LabelMode? labelMode;

  /// Custom label text, overriding [labelMode]. Return `null` to hide a
  /// region's label.
  final RegionLabelBuilder? labelBuilder;

  /// Whether to show a tooltip on hover (desktop, web) and long-press
  /// (touch).
  final bool showTooltips;

  /// Builds the tooltip. Defaults to [RegionTooltip].
  final RegionTooltipBuilder? tooltipBuilder;

  /// Whether the user can zoom and pan. Taps and hover work either way.
  final bool interactive;

  /// Smallest zoom, relative to the fitted view (1 = whole view fits).
  final double minZoom;

  /// Largest zoom, relative to the fitted view.
  final double maxZoom;

  /// Length of zoom and drill-down animations. Animations are skipped when
  /// the platform asks for reduced motion.
  final Duration animationDuration;

  /// Easing of zoom and drill-down animations.
  final Curve animationCurve;

  /// Colours and line widths. Defaults to [NepalMapTheme.of].
  final NepalMapTheme? theme;

  /// Space between the map and the widget's edges.
  final EdgeInsets padding;

  /// Shown while the data loads. Defaults to an empty box.
  final WidgetBuilder? placeholder;

  /// Shown if the data fails to load. Defaults to an empty box.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  /// Whether to show the [attribution] line in the bottom corner.
  ///
  /// The boundary data's CC BY 4.0 license requires credit. If you hide this
  /// line, credit the data elsewhere in your app (e.g. an About screen)
  /// using [attribution] and [attributionUrl].
  final bool showAttribution;

  /// Called when the attribution line is tapped, e.g. to open
  /// [attributionUrl]. When `null` the line isn't tappable.
  final VoidCallback? onAttributionTap;

  /// Where the boundary data comes from. Defaults to the bundled asset.
  final MapDataSource dataSource;

  /// Colours regions by data, with a legend. Without a [style], regions are
  /// filled by [Choropleth.scale]; with one, the value arrives in
  /// [RegionState.value].
  final Choropleth? choropleth;

  /// Points to show on the map: widgets or painted dots.
  final List<MapMarker> markers;

  /// Called when a marker is tapped. Marker taps take priority over region
  /// taps.
  final ValueChanged<MapMarker>? onMarkerTap;

  /// Whether to overlay the protected areas outside local levels (national
  /// parks, reserves) with hatching and labels. Off by default.
  final bool showProtectedAreas;

  /// Your own drawing, painted above the regions and below markers and
  /// labels. See [MapLayer].
  final List<MapLayer> extraLayers;

  @override
  State<NepalMap> createState() => _NepalMapState();
}

class _NepalMapState extends State<NepalMap>
    with TickerProviderStateMixin
    implements NepalMapDelegate {
  late Future<NepalMapData> _data;
  NepalMapController? _ownController;
  NepalMapController get _controller => widget.controller ?? _ownController!;

  /// The view being drawn. Trails the controller's view by one rebuild so a
  /// scope change can animate from where the camera was.
  MapView? _shownView;

  /// The camera; `null` means "fit the view".
  MapCamera? _camera;

  late final AnimationController _flightController =
      AnimationController(vsync: this)
        ..addListener(() => setState(() {}))
        ..addStatusListener(_onFlightStatus);
  CameraFlight? _flight;
  MapCamera? _flightEnd;
  Completer<void>? _flightDone;

  // Inputs from the last build, for gesture handlers.
  GeometryCache? _cache;
  Size _size = Size.zero;

  Region? _hovered;
  Region? _focused;
  final _boundaryKey = GlobalKey();
  Curve? _flightCurveOverride;

  // Colour transition when the choropleth changes.
  late final AnimationController _fillController = AnimationController(
    vsync: this,
    duration: _fillDuration,
  )..addListener(_rebuild);
  // Per-region styles and labels, reused while their inputs are unchanged
  // (e.g. every frame of a pan), so layers can skip work by identity.
  Object? _stylesKey;
  Map<Region, RegionStyle> _styles = const {};
  Object? _labelsKey;
  (Map<Region, String>, Map<ProtectedArea, String>) _labels = (
    const {},
    const {},
  );

  Map<Region, Color> _fillFrom = const {};
  Map<Region, Color> _lastFills = const {};
  static const _fillDuration = Duration(milliseconds: 300);
  ({Region region, Offset anchor})? _tooltip;
  ({MapCamera camera, Offset focalPlane})? _gestureStart;
  ({Duration time, Offset position})? _lastTap;
  final _focusNode = FocusNode(debugLabel: 'NepalMap');

  final _recordings = <LayerRecording>[];
  final _labelCache = LabelCache();

  /// Width / height of Nepal, used for sizing before the data has loaded.
  static const _nepalAspectRatio = 1.74;
  static const _doubleTapTime = Duration(milliseconds: 300);
  static const _doubleTapSlop = 40.0;

  MapView get _widgetView => (level: widget.level, scope: widget.scope);

  @override
  void initState() {
    super.initState();
    _data = NepalMapData.load(widget.dataSource);
    if (widget.controller == null) _ownController = NepalMapController();
    _attach(_controller);
    _focusNode.addListener(_rebuild);
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
  }

  @override
  void didUpdateWidget(NepalMap old) {
    super.didUpdateWidget(old);
    if (old.dataSource.cacheKey != widget.dataSource.cacheKey) {
      _data = NepalMapData.load(widget.dataSource);
    }
    if (old.choropleth != widget.choropleth &&
        _lastFills.isNotEmpty &&
        !_reduceMotion) {
      // Fade from the colours on screen to the new data's colours.
      _fillFrom = _lastFills;
      _fillController.forward(from: 0);
    }
    final oldController = old.controller ?? _ownController!;
    if (widget.controller != old.controller) {
      _detach(oldController);
      if (widget.controller == null) {
        _ownController ??= NepalMapController();
      } else {
        _ownController?.dispose();
        _ownController = null;
      }
      _attach(_controller);
    } else if (old.level != widget.level || old.scope != widget.scope) {
      _adoptView(_widgetView);
    }
  }

  // Detach on deactivate, not dispose: when a keyed map is replaced, the new
  // one is mounted before the old one is disposed, and both would otherwise
  // hold the controller at once.
  @override
  void deactivate() {
    _detach(_controller);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _attach(_controller);
  }

  @override
  void dispose() {
    _ownController?.dispose();
    _flightController.dispose();
    _fillController.dispose();
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    _flightDone?.complete();
    _focusNode.dispose();
    for (final r in _recordings) {
      r.dispose();
    }
    _recordings.clear();
    _labelCache.dispose();
    super.dispose();
  }

  void _attach(NepalMapController controller) {
    controller.attach(this);
    controller.addListener(_onControllerChanged);
    controller.selection.addListener(_rebuild);
    controller.highlighted.addListener(_rebuild);
    _adoptView(_widgetView);
  }

  void _detach(NepalMapController controller) {
    controller.removeListener(_onControllerChanged);
    controller.selection.removeListener(_rebuild);
    controller.highlighted.removeListener(_rebuild);
    controller.detach(this);
  }

  /// Makes [view] the controller's view without animating. Listeners (e.g. a
  /// breadcrumb) are told after the frame, since this runs during build.
  void _adoptView(MapView view) {
    _shownView = view;
    _camera = null;
    if (_controller.adoptScope(view)) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.notifyScopeAdopted();
      });
    }
  }

  void _rebuild() => setState(() {});

  void _onHighlightMode(FocusHighlightMode mode) => setState(() {});

  /// Whether to draw the keyboard focus ring: only while the map has focus
  /// and the keyboard (not touch or mouse) is being used.
  bool get _showFocus =>
      _focused != null &&
      _focusNode.hasFocus &&
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  void _onControllerChanged() {
    final view = (level: _controller.level, scope: _controller.scope);
    if (view != _shownView) {
      final cache = _cache;
      final from = cache == null ? null : _absoluteCamera(cache);
      _shownView = view;
      _camera = null;
      _hovered = null;
      _tooltip = null;
      if (cache != null && from != null) {
        final content = cache.contentRect(view);
        _fly(from, (content.center, _fitScale(content)), end: null);
      }
      widget.onScopeChanged?.call(view.scope);
    }
    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Camera

  double _fitScale(Rect content) =>
      MapCamera.fitScale(content, _size, widget.padding);

  MapCamera _currentCamera(GeometryCache cache) {
    final content = cache.contentRect(_shownView!);
    final flight = _flight;
    if (flight == null) return _camera ?? MapCamera.fit(content);
    final (center, scale) = flight.at(_flightCurve);
    return MapCamera(center: center, zoom: scale / _fitScale(content));
  }

  (Offset, double) _absoluteCamera(GeometryCache cache) {
    final camera = _currentCamera(cache);
    return (
      camera.center,
      _fitScale(cache.contentRect(_shownView!)) * camera.zoom,
    );
  }

  double get _flightCurve => (_flightCurveOverride ?? widget.animationCurve)
      .transform(_flightController.value);

  ViewTransform _transform(GeometryCache cache) {
    final content = cache.contentRect(_shownView!);
    final flight = _flight;
    if (flight == null) {
      return (_camera ?? MapCamera.fit(content)).transform(
        content,
        _size,
        widget.padding,
      );
    }
    final (center, scale) = flight.at(_flightCurve);
    final viewport = widget.padding.deflateRect(Offset.zero & _size).center;
    return ViewTransform(scale, viewport - center * scale);
  }

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Animates from [from] to [to] (absolute centre and scale), then rests at
  /// [end] (`null` = fitted).
  Future<void> _fly(
    (Offset, double) from,
    (Offset, double) to, {
    required MapCamera? end,
    Curve? curve,
    Duration? duration,
  }) {
    _flightDone?.complete();
    _flightDone = null;
    if (_reduceMotion || widget.animationDuration == Duration.zero) {
      _flight = null;
      _flightController.stop();
      setState(() => _camera = end);
      return Future.value();
    }
    _flight = CameraFlight(from, to);
    _flightEnd = end;
    _flightCurveOverride = curve;
    final done = _flightDone = Completer<void>();
    _flightController
      ..duration = duration ?? widget.animationDuration
      ..forward(from: 0);
    return done.future;
  }

  void _onFlightStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    setState(() {
      _flight = null;
      _camera = _flightEnd;
    });
    _flightDone?.complete();
    _flightDone = null;
  }

  /// Stops any animation where it is, e.g. when the user starts a gesture.
  void _stopFlight() {
    final cache = _cache;
    if (_flight == null || cache == null) return;
    final camera = _currentCamera(cache);
    _flightController.stop();
    _flight = null;
    _camera = camera;
    _flightDone?.complete();
    _flightDone = null;
  }

  Future<void> _flyTo(MapCamera target, {required bool animate}) {
    final cache = _cache;
    if (cache == null) return Future.value();
    final content = cache.contentRect(_shownView!);
    final end = target.clamp(content, widget.minZoom, widget.maxZoom);
    if (!animate) {
      _stopFlight();
      setState(() => _camera = end);
      return Future.value();
    }
    return _fly(_absoluteCamera(cache), (
      end.center,
      _fitScale(content) * end.zoom,
    ), end: end);
  }

  @override
  Future<void> zoomTo(Region region, {required bool animate}) {
    final cache = _cache;
    if (cache == null) return Future.value();
    final content = cache.contentRect(_shownView!);
    final target = cache.plane.rectOf(cache.data.shapeOf(region).bounds);
    final zoom = _fitScale(target) / _fitScale(content);
    return _flyTo(
      MapCamera(center: target.center, zoom: zoom),
      animate: animate,
    );
  }

  @override
  Future<void> resetView({required bool animate}) {
    final cache = _cache;
    if (cache == null) return Future.value();
    return _flyTo(
      MapCamera.fit(cache.contentRect(_shownView!)),
      animate: animate,
    );
  }

  @override
  Future<void> zoomBy(double factor, {required bool animate}) {
    final cache = _cache;
    if (cache == null) return Future.value();
    final camera = _currentCamera(cache);
    return _flyTo(
      MapCamera(center: camera.center, zoom: camera.zoom * factor),
      animate: animate,
    );
  }

  @override
  Future<ui.Image> toImage({required double pixelRatio}) {
    final boundary = _boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw StateError('The map has not been laid out yet.');
    }
    return boundary.toImage(pixelRatio: pixelRatio);
  }

  @override
  Future<void> get settled => _flightDone?.future ?? Future.value();

  // ---------------------------------------------------------------------------
  // Input

  Region? _regionAt(Offset position) {
    final cache = _cache;
    if (cache == null) return null;
    final point = cache.plane.unproject(_transform(cache).toPlane(position));
    final view = _shownView!;
    final region = cache.data.regionAt(point, view.level);
    return region != null && inScope(region, view.scope) ? region : null;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.drillDown) _focusNode.requestFocus();
  }

  void _onTapUp(TapUpDetails details, Duration timeStamp) {
    final last = _lastTap;
    _lastTap = (time: timeStamp, position: details.localPosition);
    if (widget.interactive &&
        last != null &&
        timeStamp - last.time < _doubleTapTime &&
        (details.localPosition - last.position).distance < _doubleTapSlop) {
      _lastTap = null;
      _zoomAround(details.localPosition, 2, animate: true);
      return;
    }

    setState(() => _tooltip = null);
    if (_dotAt(details.localPosition) case final marker?) {
      widget.onMarkerTap?.call(marker);
      return;
    }
    final region = _regionAt(details.localPosition);
    if (region == null) return;
    _activate(region);
  }

  /// What a tap, Enter, or a screen reader's activate does to [region].
  void _activate(Region region) {
    widget.onRegionTap?.call(region);
    if (widget.drillDown && region.level != AdminLevel.localLevel) {
      unawaited(_controller.drillDown(region));
      return;
    }
    _applySelection(region);
  }

  /// The dot marker nearest [position], within its radius plus a margin.
  MapMarker? _dotAt(Offset position) {
    final cache = _cache;
    if (cache == null || widget.onMarkerTap == null) return null;
    final transform = _transform(cache);
    MapMarker? best;
    var bestDistance = double.infinity;
    for (final m in widget.markers) {
      if (!m.isDot) continue;
      final d = (transform.toScreen(cache.plane.project(m.point)) - position)
          .distance;
      if (d <= m.radius + 6 && d < bestDistance) {
        best = m;
        bestDistance = d;
      }
    }
    return best;
  }

  void _applySelection(Region region) {
    final current = widget.selected ?? _controller.selection.value;
    final next = switch (widget.selectionMode) {
      SelectionMode.none => null,
      SelectionMode.single => current.contains(region) ? <Region>{} : {region},
      SelectionMode.multi =>
        current.contains(region)
            ? ({...current}..remove(region))
            : {...current, region},
    };
    if (next == null) return;
    if (widget.selected == null) _controller.selectFromTap(next);
    widget.onSelectionChanged?.call(next);
  }

  void _zoomAround(Offset screenPoint, double factor, {required bool animate}) {
    final cache = _cache;
    if (cache == null) return;
    _stopFlight();
    final content = cache.contentRect(_shownView!);
    final camera = _currentCamera(cache);
    final planePoint = _transform(cache).toPlane(screenPoint);
    final target = MapCamera.anchored(
      planePoint: planePoint,
      screenPoint: screenPoint,
      zoom: (camera.zoom * factor).clamp(widget.minZoom, widget.maxZoom),
      content: content,
      size: _size,
      padding: widget.padding,
    );
    unawaited(_flyTo(target, animate: animate));
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (!widget.interactive || event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final scroll = event as PointerScrollEvent;
      _zoomAround(
        scroll.localPosition,
        math.pow(2, -scroll.scrollDelta.dy / 240).toDouble(),
        animate: false,
      );
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    final cache = _cache;
    if (cache == null || !widget.interactive) return;
    _stopFlight();
    _gestureStart = (
      camera: _currentCamera(cache),
      focalPlane: _transform(cache).toPlane(details.localFocalPoint),
    );
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final cache = _cache;
    final start = _gestureStart;
    if (cache == null || start == null) return;
    final content = cache.contentRect(_shownView!);
    final camera = MapCamera.anchored(
      planePoint: start.focalPlane,
      screenPoint: details.localFocalPoint,
      zoom: (start.camera.zoom * details.scale).clamp(
        widget.minZoom,
        widget.maxZoom,
      ),
      content: content,
      size: _size,
      padding: widget.padding,
    ).clamp(content, widget.minZoom, widget.maxZoom);
    setState(() {
      _camera = camera;
      _tooltip = null;
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    final start = _gestureStart;
    _gestureStart = null;
    final cache = _cache;
    final velocity = details.velocity.pixelsPerSecond;
    // Fling: keep a fast pan gliding to a stop.
    if (start == null ||
        cache == null ||
        velocity.distance < _flingMinVelocity) {
      return;
    }
    final content = cache.contentRect(_shownView!);
    final camera = _currentCamera(cache);
    final scale = _fitScale(content) * camera.zoom;
    final target = MapCamera(
      center: camera.center - velocity * _flingSeconds / scale,
      zoom: camera.zoom,
    ).clamp(content, widget.minZoom, widget.maxZoom);
    if (_reduceMotion) return;
    unawaited(
      _fly(
        (camera.center, scale),
        (target.center, scale),
        end: target,
        curve: Curves.decelerate,
        duration: const Duration(milliseconds: 600),
      ),
    );
  }

  static const _flingMinVelocity = 300.0;

  /// How far a fling glides: this many seconds of the release velocity.
  static const _flingSeconds = 0.3;

  void _onHover(PointerHoverEvent event) {
    final region = _regionAt(event.localPosition);
    final tooltip = widget.showTooltips && region != null
        ? (region: region, anchor: event.localPosition)
        : null;
    if (region != _hovered) widget.onRegionHover?.call(region);
    if (region != _hovered || tooltip != _tooltip) {
      setState(() {
        _hovered = region;
        _tooltip = tooltip;
      });
    }
  }

  void _onExit(PointerExitEvent event) {
    if (_hovered != null) widget.onRegionHover?.call(null);
    if (_hovered != null || _tooltip != null) {
      setState(() {
        _hovered = null;
        _tooltip = null;
      });
    }
  }

  void _onLongPress(LongPressStartDetails details) {
    if (!widget.showTooltips) return;
    final region = _regionAt(details.localPosition);
    setState(
      () => _tooltip = region == null
          ? null
          : (region: region, anchor: details.localPosition),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final cache = _cache;
    if (cache == null) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final regions = cache.regions(_shownView!);

    if (key == LogicalKeyboardKey.escape) {
      if (_controller.scope == null) return KeyEventResult.ignored;
      unawaited(_controller.drillUp());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      // Step through regions; past either end, let focus leave the map.
      final step = HardwareKeyboard.instance.isShiftPressed ? -1 : 1;
      final i = _focused == null
          ? (step > 0 ? 0 : regions.length - 1)
          : regions.indexOf(_focused!) + step;
      if (i < 0 || i >= regions.length) {
        _setFocused(null);
        return KeyEventResult.ignored;
      }
      _setFocused(regions[i]);
      return KeyEventResult.handled;
    }
    final direction = switch (key) {
      LogicalKeyboardKey.arrowLeft => const Offset(-1, 0),
      LogicalKeyboardKey.arrowRight => const Offset(1, 0),
      LogicalKeyboardKey.arrowUp => const Offset(0, -1),
      LogicalKeyboardKey.arrowDown => const Offset(0, 1),
      _ => null,
    };
    if (direction != null) {
      _setFocused(
        _focused == null
            ? cache.regionsByArea(_shownView!).first
            : _neighbour(cache, _focused!, direction),
      );
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) &&
        _focused != null) {
      _activate(_focused!);
      return KeyEventResult.handled;
    }
    if (widget.interactive &&
        (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.add)) {
      unawaited(zoomBy(2, animate: true));
      return KeyEventResult.handled;
    }
    if (widget.interactive && key == LogicalKeyboardKey.minus) {
      unawaited(zoomBy(0.5, animate: true));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// The region whose label anchor is nearest to [from]'s in [direction]
  /// (within 60° of it), or [from] if there is none.
  Region _neighbour(GeometryCache cache, Region from, Offset direction) {
    final origin = cache.labelAnchor(from).point;
    Region? best;
    var bestScore = double.infinity;
    for (final region in cache.regions(_shownView!)) {
      if (region == from) continue;
      final delta = cache.labelAnchor(region).point - origin;
      final along = delta.dx * direction.dx + delta.dy * direction.dy;
      final across = (delta.dx * direction.dy - delta.dy * direction.dx).abs();
      if (along <= 0 || across > along * 1.73) continue; // outside ±60°
      final score = along + across * 2;
      if (score < bestScore) {
        best = region;
        bestScore = score;
      }
    }
    return best ?? from;
  }

  /// Moves keyboard focus to [region], shows its tooltip, and pans to it if
  /// it's off screen.
  void _setFocused(Region? region) {
    final cache = _cache;
    setState(() {
      _focused = region;
      _tooltip = null;
    });
    if (region == null || cache == null) return;
    final anchor = _transform(cache).toScreen(cache.labelAnchor(region).point);
    final viewport = widget.padding.deflateRect(Offset.zero & _size);
    if (!viewport.contains(anchor)) {
      final camera = _currentCamera(cache);
      unawaited(
        _flyTo(
          MapCamera(center: cache.labelAnchor(region).point, zoom: camera.zoom),
          animate: true,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build

  @override
  Widget build(BuildContext context) {
    final view = _shownView!;
    assert(
      view.scope == null || view.scope!.level.index < view.level.index,
      'scope must be a coarser level than level, '
      'e.g. scope: Province.gandaki with level: AdminLevel.district',
    );
    return FutureBuilder<NepalMapData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _sized(
            _nepalAspectRatio,
            (_) =>
                widget.errorBuilder?.call(context, snapshot.error!) ??
                const SizedBox.shrink(),
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return _sized(
            _nepalAspectRatio,
            (_) => widget.placeholder?.call(context) ?? const SizedBox.shrink(),
          );
        }
        final cache = GeometryCache.of(data);
        final content = cache.contentRect(view);
        return _sized(
          content.width / content.height,
          (size) => _buildMap(context, cache, size),
        );
      },
    );
  }

  /// Fills the available space; with an unbounded side, keeps [aspectRatio].
  Widget _sized(double aspectRatio, Widget Function(Size size) builder) =>
      LayoutBuilder(
        builder: (context, c) {
          var width = c.hasBoundedWidth ? c.maxWidth : null;
          var height = c.hasBoundedHeight ? c.maxHeight : null;
          if (width == null && height == null) width = 400;
          width ??= height! * aspectRatio;
          height ??= width / aspectRatio;
          final size = c.constrain(Size(width, height));
          return SizedBox.fromSize(size: size, child: builder(size));
        },
      );

  MapLanguage _language(BuildContext context) =>
      _controller.language ??
      widget.language ??
      MapLanguage.fromLocaleCode(
        Localizations.maybeLocaleOf(context)?.languageCode,
      );

  Widget _buildMap(BuildContext context, GeometryCache cache, Size size) {
    _cache = cache;
    _size = size;
    final view = _shownView!;
    final language = _language(context);
    final strings = widget.strings ?? NepalMapStrings.of(language);
    final theme = widget.theme ?? NepalMapTheme.of(context);
    final choropleth = widget.choropleth;
    final styleOf =
        widget.style ?? choropleth?.defaultStyle(theme) ?? theme.defaultStyle;
    final selection = widget.selected ?? _controller.selection.value;
    final highlighted = _controller.highlighted.value;
    final regions = cache.regions(view);
    final transform = _transform(cache);

    final labelMode =
        widget.labelMode ??
        (language == MapLanguage.ne ? LabelMode.ne : LabelMode.en);
    final labels = _memoLabels(cache, view, regions, labelMode, language);
    final paintContext = MapPaintContext(
      cache: cache,
      view: view,
      transform: transform,
      theme: theme,
      language: language,
      styles: _memoStyles(
        regions,
        styleOf,
        choropleth,
        theme,
        selection,
        highlighted,
      ),
      labels: labels.$1,
      protectedAreaLabels: labels.$2,
      labelStyle: DefaultTextStyle.of(context).style
          .merge(const TextStyle(fontSize: 11, fontWeight: FontWeight.w500))
          .merge(theme.labelStyle),
    );

    final layers = <MapLayer>[
      const RegionFillLayer(),
      if (widget.showProtectedAreas) const ProtectedAreaLayer(),
      const BorderLayer(),
      const HighlightLayer(),
      ...widget.extraLayers,
      if (widget.markers.any((m) => m.isDot))
        MarkerDotLayer(widget.markers, Theme.of(context).colorScheme.primary),
      LabelLayer(_labelCache),
    ];
    while (_recordings.length < layers.length) {
      _recordings.add(LayerRecording());
    }

    final focusTip = _showFocus && widget.showTooltips
        ? (
            region: _focused!,
            anchor: transform.toScreen(cache.labelAnchor(_focused!).point),
          )
        : null;
    final tooltip = _tooltip ?? focusTip;
    Widget map = Stack(
      fit: StackFit.expand,
      children: [
        if (SemanticsBinding.instance.semanticsEnabled)
          CustomPaint(
            painter: RegionSemanticsPainter(
              cache: cache,
              view: view,
              transform: transform,
              labels: {
                for (final r in regions)
                  r: _semanticLabel(r, language, choropleth),
              },
              selection: selection,
              onActivate: _activate,
            ),
          ),
        for (final (i, layer) in layers.indexed)
          RepaintBoundary(
            child: CustomPaint(
              painter: MapLayerPainter(layer, paintContext, _recordings[i]),
            ),
          ),
        for (final marker in widget.markers)
          if (!marker.isDot)
            ?_positioned(
              marker,
              transform.toScreen(cache.plane.project(marker.point)),
              size,
            ),
        if (choropleth != null && choropleth.showLegend)
          Align(
            alignment: choropleth.legendAlignment,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              child: NepalMapLegend.of(
                choropleth,
                language: language,
                showNoData: regions.any(
                  (r) => !choropleth.values.containsKey(r),
                ),
                noDataColor: theme.noDataFill,
              ),
            ),
          ),
        if (tooltip case final tip?)
          IgnorePointer(
            child: CustomSingleChildLayout(
              delegate: RegionTooltipPositionDelegate(tip.anchor),
              child:
                  widget.tooltipBuilder?.call(context, tip.region, language) ??
                  RegionTooltip(
                    region: tip.region,
                    language: language,
                    value: switch (choropleth?.values[tip.region]) {
                      final v? => choropleth!.format(v, language),
                      null => null,
                    },
                    valueLabel: choropleth?.title?.of(language),
                  ),
            ),
          ),
        if (widget.showAttribution)
          Positioned(
            right: 4,
            bottom: 2,
            child: _Attribution(
              style: theme.attributionStyle,
              onTap: widget.onAttributionTap,
            ),
          ),
      ],
    );

    map = RepaintBoundary(key: _boundaryKey, child: map);

    map = _TapWithTime(
      onTapUp: _onTapUp,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: _onLongPress,
        onScaleStart: widget.interactive ? _onScaleStart : null,
        onScaleUpdate: widget.interactive ? _onScaleUpdate : null,
        onScaleEnd: widget.interactive ? _onScaleEnd : null,
        child: map,
      ),
    );

    return _FadeIn(
      enabled: !_reduceMotion,
      child: Semantics(
        container: true,
        label: view.scope?.fullName(language) ?? strings.country,
        child: Focus(
          focusNode: _focusNode,
          onKeyEvent: _onKey,
          child: Listener(
            onPointerDown: _onPointerDown,
            onPointerSignal: _onPointerSignal,
            child: MouseRegion(
              cursor: _hovered != null
                  ? SystemMouseCursors.click
                  : MouseCursor.defer,
              onHover: _onHover,
              onExit: _onExit,
              child: map,
            ),
          ),
        ),
      ),
    );
  }

  Map<Region, RegionStyle> _memoStyles(
    List<Region> regions,
    RegionStyleBuilder styleOf,
    Choropleth? choropleth,
    NepalMapTheme theme,
    Set<Region> selection,
    Set<Region> highlighted,
  ) {
    final focused = _showFocus ? _focused : null;
    final transition = _fillController.isAnimating
        ? _fillController.value
        : null;
    final key = (
      regions,
      widget.style,
      choropleth,
      theme,
      selection,
      highlighted,
      _hovered,
      focused,
      transition,
    );
    if (key == _stylesKey) return _styles;
    _stylesKey = key;
    return _styles = _transitionFills({
      for (final region in regions)
        region: styleOf(
          region,
          RegionState(
            isSelected: selection.contains(region),
            isHovered: region == _hovered,
            isHighlighted: highlighted.contains(region),
            isFocused: region == focused,
            value: choropleth?.values[region],
          ),
        ),
    });
  }

  (Map<Region, String>, Map<ProtectedArea, String>) _memoLabels(
    GeometryCache cache,
    MapView view,
    List<Region> regions,
    LabelMode labelMode,
    MapLanguage language,
  ) {
    final key = (
      view,
      labelMode,
      language,
      widget.labelBuilder,
      widget.showProtectedAreas,
    );
    if (key == _labelsKey) return _labels;
    _labelsKey = key;
    return _labels = (
      {
        if (labelMode != LabelMode.none || widget.labelBuilder != null)
          for (final region in regions)
            if (_labelText(region, labelMode, language) case final text?)
              region: text,
      },
      {
        if (widget.showProtectedAreas && labelMode != LabelMode.none)
          for (final area in cache.protectedAreasIn(view.scope))
            area: switch (labelMode) {
              LabelMode.both =>
                '${area.fullName(MapLanguage.en)}\n${area.fullName(MapLanguage.ne)}',
              LabelMode.ne => area.fullName(MapLanguage.ne),
              _ => area.fullName(MapLanguage.en),
            },
      },
    );
  }

  /// While the colour transition runs, blends each region's fill from the
  /// colour it had to its new one. Remembers the fills for the next change.
  Map<Region, RegionStyle> _transitionFills(Map<Region, RegionStyle> targets) {
    var styles = targets;
    if (_fillController.isAnimating) {
      final t = Curves.easeInOut.transform(_fillController.value);
      styles = {
        for (final MapEntry(key: region, value: style) in targets.entries)
          region: switch (_fillFrom[region]) {
            final from? => style.copyWith(
              fill: Color.lerp(from, style.fill, t),
            ),
            null => style,
          },
      };
    }
    _lastFills = {
      for (final MapEntry(:key, :value) in styles.entries) key: value.fill,
    };
    return styles;
  }

  /// What a screen reader says for [region]: its full name and parent, plus
  /// its value on a choropleth map.
  String _semanticLabel(
    Region region,
    MapLanguage language,
    Choropleth? choropleth,
  ) {
    final parent = switch (region) {
      Province() => null,
      District(:final province) => province.fullName(language),
      LocalLevel(:final district) => district.fullName(language),
    };
    final value = choropleth?.values[region];
    return [
      region.fullName(language),
      ?parent,
      if (value != null)
        [
          ?choropleth!.title?.of(language),
          choropleth.format(value, language),
        ].join(': '),
    ].join(', ');
  }

  /// A widget marker positioned so its [MapMarker.alignment] point sits on
  /// [screen], or `null` if it's off the map.
  Widget? _positioned(MapMarker marker, Offset screen, Size size) {
    final left = screen.dx - marker.size.width * (marker.alignment.x + 1) / 2;
    final top = screen.dy - marker.size.height * (marker.alignment.y + 1) / 2;
    final rect = Rect.fromLTWH(
      left,
      top,
      marker.size.width,
      marker.size.height,
    );
    if (!rect.overlaps(Offset.zero & size)) return null;
    final onTap = widget.onMarkerTap;
    return Positioned.fromRect(
      rect: rect,
      child: onTap == null
          ? marker.child!
          : GestureDetector(onTap: () => onTap(marker), child: marker.child),
    );
  }

  String? _labelText(Region region, LabelMode mode, MapLanguage language) =>
      widget.labelBuilder != null
      ? widget.labelBuilder!(region, language)
      : mode.textOf(region);
}

/// A tap recognizer that also reports the pointer-down time stamp, for
/// double-tap detection without delaying single taps.
///
/// Flutter's `onDoubleTap` holds every single tap back until the double-tap
/// window closes; here the first tap acts at once and a quick second tap
/// zooms instead.
class _TapWithTime extends StatefulWidget {
  const _TapWithTime({required this.onTapUp, required this.child});

  final void Function(TapUpDetails details, Duration timeStamp) onTapUp;
  final Widget child;

  @override
  State<_TapWithTime> createState() => _TapWithTimeState();
}

class _TapWithTimeState extends State<_TapWithTime> {
  Duration _downTime = Duration.zero;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) => _downTime = event.timeStamp,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => widget.onTapUp(details, _downTime),
      child: widget.child,
    ),
  );
}

class _Attribution extends StatelessWidget {
  const _Attribution({required this.style, required this.onTap});

  final TextStyle? style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Text(
      NepalMap.attribution,
      style:
          style ??
          theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 9,
          ),
    );
    // Its own semantics node, so it isn't merged into the map's label.
    return Semantics(
      container: true,
      link: onTap != null,
      child: onTap == null
          ? text
          : MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(onTap: onTap, child: text),
            ),
    );
  }
}

/// Fades the map in once, when its data first appears.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: child,
    );
  }
}
