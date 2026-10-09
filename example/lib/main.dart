import 'package:flutter/material.dart';
import 'package:nepal_administrative_map/nepal_administrative_map.dart';

void main() {
  // Optional: start decoding the map data before the first frame.
  NepalMap.preload();
  runApp(const ExampleApp());
}

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
  AdminLevel _level = AdminLevel.district;
  Province? _scope;
  MapLanguage _language = MapLanguage.en;
  Region? _tapped;

  bool get _ne => _language == MapLanguage.ne;

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
            onSelectionChanged: (s) => setState(() => _language = s.single),
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
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
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
            ),
          ),
          Expanded(
            child: NepalMap(
              key: ValueKey((_level, _scope)),
              level: _level,
              scope: _scope,
              language: _language,
              onRegionTap: (region) => setState(() => _tapped = region),
              placeholder: (_) =>
                  const Center(child: CircularProgressIndicator()),
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

  String _describe(Region region) => switch (region) {
    Province() => region.fullName(_language),
    District() =>
      '${region.fullName(_language)} · ${region.province.fullName(_language)}',
    LocalLevel() =>
      '${region.fullName(_language)} · ${region.district.fullName(_language)} · '
          '${region.province.fullName(_language)}',
  };
}
