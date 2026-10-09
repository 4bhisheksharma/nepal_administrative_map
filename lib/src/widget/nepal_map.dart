import 'package:flutter/material.dart';

import '../data/loader/map_data_source.dart';
import '../data/loader/nepal_map_data.dart';
import '../data/models/region.dart';
import '../i18n/map_language.dart';
import '../i18n/nepal_map_strings.dart';
import '../rendering/asset_map_data_source.dart';
import '../rendering/geometry_cache.dart';
import '../rendering/layers/border_layer.dart';
import '../rendering/layers/highlight_layer.dart';
import '../rendering/layers/region_fill_layer.dart';
import '../rendering/map_layer.dart';
import '../rendering/map_plane.dart';
import '../rendering/style/nepal_map_theme.dart';
import '../rendering/style/region_style.dart';

/// How tapping regions changes the selection.
enum SelectionMode {
  /// Taps don't select (`onRegionTap` still fires).
  none,

  /// At most one region is selected; tapping it again deselects it.
  single,

  /// Taps toggle regions in and out of the selection.
  multi,
}

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
/// Every parameter is optional; `NepalMap()` shows the 7 provinces.
class NepalMap extends StatefulWidget {
  /// Creates a map.
  const NepalMap({
    super.key,
    this.level = AdminLevel.province,
    this.scope,
    this.style,
    this.onRegionTap,
    this.selectionMode = SelectionMode.single,
    this.selected,
    this.onSelectionChanged,
    this.language,
    this.strings,
    this.theme,
    this.padding = const EdgeInsets.all(8),
    this.placeholder,
    this.errorBuilder,
    this.showAttribution = true,
    this.onAttributionTap,
    this.dataSource = const AssetMapDataSource(),
  });

  /// Credit line for the boundary data, required by its CC BY 4.0 license.
  static const String attribution =
      'Boundary data © OKNP LocalBoundaries, CC BY 4.0';

  /// Link to the data license.
  static const String attributionUrl =
      'https://creativecommons.org/licenses/by/4.0/';

  /// Loads the bundled map data ahead of time, e.g. during a splash screen,
  /// so the first map appears without a loading state.
  static Future<void> preload({
    MapDataSource source = const AssetMapDataSource(),
  }) => NepalMapData.load(source);

  /// Which regions to draw.
  final AdminLevel level;

  /// Only show regions inside this province or district, zoomed to fit it.
  /// Must be a coarser level than [level].
  final Region? scope;

  /// How each region is drawn. Defaults to [NepalMapTheme.defaultStyle].
  final RegionStyleBuilder? style;

  /// Called when a region is tapped.
  final ValueChanged<Region>? onRegionTap;

  /// How taps change the selection.
  final SelectionMode selectionMode;

  /// The selected regions, if you manage the selection yourself. When
  /// `null`, the map keeps its own selection.
  final Set<Region>? selected;

  /// Called with the new selection after a tap changes it.
  final ValueChanged<Set<Region>>? onSelectionChanged;

  /// The language for names and text. Defaults to the app's locale: Nepali
  /// for `ne`, English otherwise.
  final MapLanguage? language;

  /// Replaces the built-in UI strings, whatever the [language].
  final NepalMapStrings? strings;

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

  @override
  State<NepalMap> createState() => _NepalMapState();
}

class _NepalMapState extends State<NepalMap> {
  late Future<NepalMapData> _data;
  Set<Region> _ownSelection = const {};

  /// Width / height of Nepal, used for sizing before the data has loaded.
  static const _nepalAspectRatio = 1.74;

  Set<Region> get _selection => widget.selected ?? _ownSelection;

  @override
  void initState() {
    super.initState();
    _data = NepalMapData.load(widget.dataSource);
  }

  @override
  void didUpdateWidget(NepalMap old) {
    super.didUpdateWidget(old);
    if (old.dataSource.cacheKey != widget.dataSource.cacheKey) {
      _data = NepalMapData.load(widget.dataSource);
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.scope == null || widget.scope!.level.index < widget.level.index,
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
        final view = (level: widget.level, scope: widget.scope);
        final content = cache.contentRect(view);
        return _sized(
          content.width / content.height,
          (size) => _buildMap(context, data, cache, view, size),
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

  Widget _buildMap(
    BuildContext context,
    NepalMapData data,
    GeometryCache cache,
    MapView view,
    Size size,
  ) {
    final language =
        widget.language ??
        MapLanguage.fromLocaleCode(
          Localizations.maybeLocaleOf(context)?.languageCode,
        );
    final strings = widget.strings ?? NepalMapStrings.of(language);
    final theme = widget.theme ?? NepalMapTheme.of(context);
    final styleOf = widget.style ?? theme.defaultStyle;
    final selection = _selection;
    final transform = ViewTransform.fit(
      cache.contentRect(view),
      size,
      widget.padding,
    );
    final paintContext = MapPaintContext(
      cache: cache,
      view: view,
      transform: transform,
      theme: theme,
      language: language,
      styles: {
        for (final region in cache.regions(view))
          region: styleOf(
            region,
            RegionState(isSelected: selection.contains(region)),
          ),
      },
    );

    return Semantics(
      container: true,
      label: widget.scope?.fullName(language) ?? strings.country,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) =>
            _handleTap(data, cache, transform, details.localPosition),
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (final layer in const [
              RegionFillLayer(),
              BorderLayer(),
              HighlightLayer(),
            ])
              RepaintBoundary(
                child: CustomPaint(
                  painter: MapLayerPainter(layer, paintContext),
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
        ),
      ),
    );
  }

  void _handleTap(
    NepalMapData data,
    GeometryCache cache,
    ViewTransform transform,
    Offset position,
  ) {
    final point = cache.plane.unproject(transform.toPlane(position));
    final region = data.regionAt(point, widget.level);
    if (region == null || !inScope(region, widget.scope)) return;

    widget.onRegionTap?.call(region);
    final current = _selection;
    final next = switch (widget.selectionMode) {
      SelectionMode.none => current,
      SelectionMode.single => current.contains(region) ? <Region>{} : {region},
      SelectionMode.multi =>
        current.contains(region)
            ? ({...current}..remove(region))
            : {...current, region},
    };
    if (identical(next, current)) return;
    if (widget.selected == null) {
      setState(() => _ownSelection = Set.unmodifiable(next));
    }
    widget.onSelectionChanged?.call(next);
  }
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
