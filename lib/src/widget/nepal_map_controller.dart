import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../data/models/region.dart';
import '../i18n/map_language.dart';
import '../rendering/geometry_cache.dart';

/// What a controller needs from the map it's attached to.
abstract interface class NepalMapDelegate {
  /// Animates (or jumps) the camera to show [region].
  Future<void> zoomTo(Region region, {required bool animate});

  /// Animates (or jumps) back to the whole view.
  Future<void> resetView({required bool animate});

  /// Zooms by [factor] around the view's centre.
  Future<void> zoomBy(double factor, {required bool animate});

  /// Waits for the camera animation started by a scope change, if any.
  Future<void> get settled;

  /// Renders the map as it is on screen.
  Future<ui.Image> toImage({required double pixelRatio});
}

/// Controls a [NepalMap] from outside: selection, highlights, zoom,
/// drill-down and language.
///
/// ```dart
/// final controller = NepalMapController();
///
/// NepalMap(controller: controller, drillDown: true);
///
/// controller.select(District.kaski);
/// controller.zoomTo(Province.koshi);
/// controller.language = MapLanguage.ne;
/// ```
///
/// Listen to the controller for scope and language changes, and to
/// [selection] for the selection. Dispose it when you're done.
class NepalMapController extends ChangeNotifier {
  /// Creates a controller.
  NepalMapController({MapLanguage? language, Set<Region> selection = const {}})
    // Named parameters can't be private, so no initializing formal.
    // ignore: prefer_initializing_formals
    : _language = language,
      _selection = ValueNotifier(Set.unmodifiable(selection));

  final ValueNotifier<Set<Region>> _selection;
  final ValueNotifier<Set<Region>> _highlighted = ValueNotifier(const {});
  MapLanguage? _language;
  MapView _view = (level: AdminLevel.province, scope: null);
  NepalMapDelegate? _map;

  /// The selected regions.
  ValueListenable<Set<Region>> get selection => _selection;

  /// Regions marked with [highlight].
  ValueListenable<Set<Region>> get highlighted => _highlighted;

  /// The language override, or `null` to use the map's `language` (or the
  /// app locale). Setting it notifies listeners.
  MapLanguage? get language => _language;

  set language(MapLanguage? value) {
    if (value == _language) return;
    _language = value;
    notifyListeners();
  }

  /// The level the map currently shows.
  AdminLevel get level => _view.level;

  /// The region the map is limited to, or `null` for all of Nepal.
  Region? get scope => _view.scope;

  /// Whether a map is attached.
  bool get isAttached => _map != null;

  /// Replaces the selection with [region].
  void select(Region region) => _setSelection({region});

  /// Adds [region] to the selection.
  void addToSelection(Region region) =>
      _setSelection({..._selection.value, region});

  /// Removes [region] from the selection.
  void deselect(Region region) =>
      _setSelection({..._selection.value}..remove(region));

  /// Replaces the selection with [regions].
  void setSelection(Iterable<Region> regions) => _setSelection(regions.toSet());

  /// Empties the selection.
  void clearSelection() => _setSelection(const {});

  /// Marks [regions] (e.g. search results) with the theme's highlight
  /// outline, replacing any previous highlight.
  void highlight(Iterable<Region> regions) =>
      _highlighted.value = Set.unmodifiable(regions.toSet());

  /// Removes every highlight.
  void clearHighlight() => _highlighted.value = const {};

  /// Moves the camera to show [region].
  Future<void> zoomTo(Region region, {bool animate = true}) async =>
      _map?.zoomTo(region, animate: animate);

  /// Moves the camera back to the whole view (country or scope).
  Future<void> resetView({bool animate = true}) async =>
      _map?.resetView(animate: animate);

  /// Zooms in one step.
  Future<void> zoomIn({bool animate = true}) async =>
      _map?.zoomBy(2, animate: animate);

  /// Zooms out one step.
  Future<void> zoomOut({bool animate = true}) async =>
      _map?.zoomBy(0.5, animate: animate);

  /// Renders the map as currently shown (including the legend, markers and
  /// attribution) at [pixelRatio] times its logical size.
  ///
  /// Throws a [StateError] if no map is attached.
  Future<ui.Image> toImage({double pixelRatio = 1}) {
    final map = _map;
    if (map == null) {
      throw StateError('No NepalMap is attached to this controller.');
    }
    return map.toImage(pixelRatio: pixelRatio);
  }

  /// Renders the map as PNG bytes, e.g. to save or share. See [toImage].
  Future<Uint8List> toPngBytes({double pixelRatio = 1}) async {
    final image = await toImage(pixelRatio: pixelRatio);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// Shows the regions one level below [region], inside it: a province's
  /// districts or a district's local levels. Does nothing for a local level.
  Future<void> drillDown(Region region) async {
    final child = _childLevel(region.level);
    if (child == null) return;
    _setView((level: child, scope: region));
    await _map?.settled;
  }

  /// Goes back up one level: a district's local levels → its province's
  /// districts → all provinces. Does nothing at the top.
  Future<void> drillUp() async {
    final scope = _view.scope;
    if (scope == null) return;
    _setView(switch (scope) {
      District(:final province) => (
        level: AdminLevel.district,
        scope: province,
      ),
      _ => (level: AdminLevel.province, scope: null),
    });
    await _map?.settled;
  }

  /// Shows the children of [scope], or all provinces when `null`.
  Future<void> drillTo(Region? scope) async {
    if (scope == null) {
      _setView((level: AdminLevel.province, scope: null));
      await _map?.settled;
    } else {
      await drillDown(scope);
    }
  }

  void _setSelection(Set<Region> regions) {
    if (setEquals(regions, _selection.value)) return;
    _selection.value = Set.unmodifiable(regions);
  }

  void _setView(MapView view) {
    if (view == _view) return;
    _view = view;
    notifyListeners();
  }

  void _notify() => notifyListeners();

  static AdminLevel? _childLevel(AdminLevel level) => switch (level) {
    AdminLevel.province => AdminLevel.district,
    AdminLevel.district => AdminLevel.localLevel,
    AdminLevel.localLevel => null,
  };

  @override
  void dispose() {
    _selection.dispose();
    _highlighted.dispose();
    super.dispose();
  }
}

/// Wiring between [NepalMapController] and the map. Not exported.
extension NepalMapControllerInternals on NepalMapController {
  /// Attaches [map]. A controller drives one map at a time.
  void attach(NepalMapDelegate map) {
    assert(
      _map == null || identical(_map, map),
      'A NepalMapController can only be attached to one NepalMap at a time.',
    );
    _map = map;
  }

  /// Detaches [map] if it's the attached one.
  void detach(NepalMapDelegate map) {
    if (identical(_map, map)) _map = null;
  }

  /// Sets the view without notifying, e.g. from the widget's properties
  /// during build. Returns whether it changed; if so, call
  /// [notifyScopeAdopted] after the frame.
  bool adoptScope(MapView view) {
    if (view == _view) return false;
    _view = view;
    return true;
  }

  /// Tells listeners about a view set with [adoptScope].
  void notifyScopeAdopted() => _notify();

  /// Applies a selection change from a tap.
  void selectFromTap(Set<Region> regions) => _setSelection(regions);
}
