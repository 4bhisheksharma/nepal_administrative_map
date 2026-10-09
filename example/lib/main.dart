import 'package:flutter/material.dart';
import 'package:nepal_administrative_map/nepal_administrative_map.dart';

import 'cities.dart';
import 'city_glow_layer.dart';

void main() {
  // Optional: start decoding the map data before the first frame.
  NepalMap.preload();
  runApp(const ExampleApp());
}

/// What the example colours regions by.
enum ColourBy { nothing, area, localLevels }

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nepal Administrative Map',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: MapPage(
        dark: _themeMode == ThemeMode.dark,
        onDarkChanged: (dark) => setState(
          () => _themeMode = dark ? ThemeMode.dark : ThemeMode.light,
        ),
      ),
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.dark, required this.onDarkChanged});

  final bool dark;
  final ValueChanged<bool> onDarkChanged;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _controller = NepalMapController(language: MapLanguage.en);
  bool _drillDown = true;
  AdminLevel _level = AdminLevel.district;
  Province? _scope;
  bool _bilingualLabels = false;
  bool _protectedAreas = false;
  bool _cityMarkers = false;
  ColourBy _colourBy = ColourBy.nothing;
  NepalMapData? _data;
  Region? _tapped;

  @override
  void initState() {
    super.initState();
    NepalMap.preload().then((data) {
      if (mounted) setState(() => _data = data);
    });
  }

  MapLanguage get _language => _controller.language ?? MapLanguage.en;
  bool get _ne => _language == MapLanguage.ne;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _ne ? 'नेपालको प्रशासनिक नक्सा' : 'Nepal Administrative Map',
        ),
        actions: [
          SegmentedButton<MapLanguage>(
            segments: const [
              ButtonSegment(value: MapLanguage.en, label: Text('EN')),
              ButtonSegment(value: MapLanguage.ne, label: Text('नेपाली')),
            ],
            selected: {_language},
            showSelectedIcon: false,
            onSelectionChanged: (s) =>
                setState(() => _controller.language = s.single),
          ),
          IconButton(
            tooltip: widget.dark ? 'Light mode' : 'Dark mode',
            icon: Icon(widget.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => widget.onDarkChanged(!widget.dark),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Switch(
                  label: _ne ? 'तह अनुसार खोल्नुहोस्' : 'Drill down',
                  value: _drillDown,
                  onChanged: (v) => setState(() {
                    _drillDown = v;
                    _tapped = null;
                  }),
                ),
                _Switch(
                  label: _ne ? 'दुवै भाषामा नाम' : 'Bilingual labels',
                  value: _bilingualLabels,
                  onChanged: (v) => setState(() => _bilingualLabels = v),
                ),
                _Switch(
                  label: _ne ? 'संरक्षित क्षेत्र' : 'Protected areas',
                  value: _protectedAreas,
                  onChanged: (v) => setState(() => _protectedAreas = v),
                ),
                _Switch(
                  label: _ne ? 'शहरहरू' : 'Cities',
                  value: _cityMarkers,
                  onChanged: (v) => setState(() => _cityMarkers = v),
                ),
                DropdownButton<ColourBy>(
                  value: _colourBy,
                  items: [
                    DropdownMenuItem(
                      value: ColourBy.nothing,
                      child: Text(_ne ? 'रङ: छैन' : 'Colour: none'),
                    ),
                    DropdownMenuItem(
                      value: ColourBy.area,
                      child: Text(_ne ? 'रङ: क्षेत्रफल' : 'Colour: area'),
                    ),
                    DropdownMenuItem(
                      value: ColourBy.localLevels,
                      child: Text(
                        _ne ? 'रङ: स्थानीय तह' : 'Colour: local levels',
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _colourBy = v!),
                ),
                SizedBox(
                  width: 260,
                  child: NepalMapSearchField(controller: _controller),
                ),
                if (!_drillDown) ...[
                  SegmentedButton<AdminLevel>(
                    segments: [
                      for (final level in AdminLevel.values)
                        if (_scope == null || level != AdminLevel.province)
                          ButtonSegment(
                            value: level,
                            label: Text(level.label.of(_language)),
                          ),
                    ],
                    selected: {_level},
                    onSelectionChanged: (s) => setState(() {
                      _level = s.single;
                      _tapped = null;
                    }),
                  ),
                  DropdownButton<Province?>(
                    value: _scope,
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(_ne ? 'सम्पूर्ण नेपाल' : 'All of Nepal'),
                      ),
                      for (final p in Province.values)
                        DropdownMenuItem(
                          value: p,
                          child: Text(p.fullName(_language)),
                        ),
                    ],
                    onChanged: (p) => setState(() {
                      _scope = p;
                      if (p != null && _level == AdminLevel.province) {
                        _level = AdminLevel.district;
                      }
                      _tapped = null;
                    }),
                  ),
                ],
              ],
            ),
          ),
          if (_drillDown)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: NepalMapBreadcrumb(controller: _controller),
            ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  // Rebuild when drilling so the choropleth matches the level.
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => NepalMap(
                      key: ValueKey((_drillDown, _level, _scope)),
                      controller: _controller,
                      drillDown: _drillDown,
                      level: _drillDown ? AdminLevel.province : _level,
                      scope: _drillDown ? null : _scope,
                      labelMode: _bilingualLabels ? LabelMode.both : null,
                      onRegionTap: (region) => setState(() => _tapped = region),
                      placeholder: (_) =>
                          const Center(child: CircularProgressIndicator()),
                      choropleth: _choropleth(
                        _drillDown ? _controller.level : _level,
                      ),
                      showProtectedAreas: _protectedAreas,
                      markers: [
                        if (_cityMarkers)
                          for (final (en, ne, point) in cities)
                            MapMarker(
                              point: point,
                              data: _ne ? ne : en,
                              child: Icon(
                                Icons.location_on,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                      ],
                      onMarkerTap: (marker) => ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(content: Text('${marker.data}')),
                        ),
                      extraLayers: [
                        if (_cityMarkers)
                          CityGlowLayer([
                            for (final c in cities) c.$3,
                          ], Theme.of(context).colorScheme.error),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: _ZoomButtons(controller: _controller),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              switch (_tapped) {
                null => _ne ? 'कुनै क्षेत्रमा ट्याप गर्नुहोस्' : 'Tap a region',
                final r => _describe(r),
              },
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// Values for every region at [level]: computed from the boundaries
  /// (area) or the gazetteer (number of local levels), so nothing is made up.
  Choropleth? _choropleth(AdminLevel level) {
    final data = _data;
    if (data == null || _colourBy == ColourBy.nothing) return null;
    return switch (_colourBy) {
      ColourBy.nothing => null,
      ColourBy.area => Choropleth(
        values: {
          for (final s in data.shapesOf(level)) s.feature: s.areaKm2.round(),
        },
        scale: ColorScale.sequential(
          Colors.amber.shade50,
          Colors.deepOrange.shade800,
        ),
        title: const LocalizedName('Area (km²)', 'क्षेत्रफल (वर्ग कि.मी.)'),
      ),
      ColourBy.localLevels =>
        level == AdminLevel.localLevel
            ? Choropleth(
                values: {for (final l in LocalLevel.values) l: l.type},
                scale: ColorScale.categorical(
                  {
                    for (final t in LocalLevelType.values)
                      t: _typeColours[t.index],
                  },
                  labels: {for (final t in LocalLevelType.values) t: t.label},
                ),
                title: const LocalizedName('Type', 'प्रकार'),
              )
            : Choropleth(
                values: {
                  for (final r in Nepal.regionsAt(level))
                    r: switch (r) {
                      Province() => r.localLevels.length,
                      District() => r.localLevels.length,
                      LocalLevel() => 1,
                    },
                },
                scale: ColorScale.sequential(
                  Colors.teal.shade50,
                  Colors.teal.shade800,
                ),
                title: const LocalizedName('Local levels', 'स्थानीय तह'),
              ),
    };
  }

  static const _typeColours = [
    Color(0xFF6A1B9A),
    Color(0xFF1565C0),
    Color(0xFF26A69A),
    Color(0xFFC5E1A5),
  ];

  String _describe(Region region) => switch (region) {
    Province() => region.fullName(_language),
    District() =>
      '${region.fullName(_language)} · ${region.province.fullName(_language)}',
    LocalLevel() =>
      '${region.fullName(_language)} · ${region.district.fullName(_language)} · '
          '${region.province.fullName(_language)}',
  };
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Switch(value: value, onChanged: onChanged),
      const SizedBox(width: 6),
      Text(label),
    ],
  );
}

class _ZoomButtons extends StatelessWidget {
  const _ZoomButtons({required this.controller});

  final NepalMapController controller;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Zoom in',
          icon: const Icon(Icons.add),
          onPressed: controller.zoomIn,
        ),
        IconButton(
          tooltip: 'Zoom out',
          icon: const Icon(Icons.remove),
          onPressed: controller.zoomOut,
        ),
        IconButton(
          tooltip: 'Reset view',
          icon: const Icon(Icons.center_focus_strong),
          onPressed: controller.resetView,
        ),
        IconButton(
          tooltip: 'Export PNG',
          icon: const Icon(Icons.image_outlined),
          onPressed: () async {
            final png = await controller.toPngBytes(pixelRatio: 2);
            if (!context.mounted) return;
            await showDialog<void>(
              context: context,
              builder: (context) => Dialog(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.memory(png, width: 480),
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}
