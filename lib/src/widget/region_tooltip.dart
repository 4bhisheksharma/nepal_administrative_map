import 'package:flutter/material.dart';

import '../data/models/region.dart';
import '../i18n/map_language.dart';

/// Builds the tooltip shown for a region on hover or long-press.
typedef RegionTooltipBuilder = Widget Function(
  BuildContext context,
  Region region,
  MapLanguage language,
);

/// The default tooltip: the region's full name and, below it, its parent.
class RegionTooltip extends StatelessWidget {
  /// Creates a tooltip for [region] in [language].
  const RegionTooltip({
    super.key,
    required this.region,
    required this.language,
  });

  /// The region to describe.
  final Region region;

  /// The language to describe it in.
  final MapLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parent = switch (region) {
      Province() => null,
      District(:final province) => province.fullName(language),
      LocalLevel(:final district) =>
        '${district.fullName(language)}, ${district.province.fullName(language)}',
    };
    return Material(
      color: theme.colorScheme.inverseSurface,
      elevation: 2,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: DefaultTextStyle(
          style: theme.textTheme.bodySmall!.copyWith(
            color: theme.colorScheme.onInverseSurface,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                region.fullName(language),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (parent != null) Text(parent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Places a tooltip next to [anchor], flipping and clamping it so it stays
/// inside the map.
class RegionTooltipPositionDelegate extends SingleChildLayoutDelegate {
  /// Creates a delegate for a tooltip pointing at [anchor].
  const RegionTooltipPositionDelegate(this.anchor);

  /// The pointer position, in the map's coordinates.
  final Offset anchor;

  static const _gap = 14.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen().copyWith(
        maxWidth: constraints.maxWidth.clamp(0.0, 280.0),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var x = anchor.dx + _gap;
    if (x + childSize.width > size.width) {
      x = anchor.dx - _gap - childSize.width;
    }
    var y = anchor.dy + _gap;
    if (y + childSize.height > size.height) {
      y = anchor.dy - _gap - childSize.height;
    }
    return Offset(
      x.clamp(0.0, (size.width - childSize.width).clamp(0.0, double.infinity)),
      y.clamp(
        0.0,
        (size.height - childSize.height).clamp(0.0, double.infinity),
      ),
    );
  }

  @override
  bool shouldRelayout(RegionTooltipPositionDelegate oldDelegate) =>
      oldDelegate.anchor != anchor;
}
