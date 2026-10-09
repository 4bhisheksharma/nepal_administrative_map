/// Interactive administrative map of Nepal: 7 provinces, 77 districts and
/// 753 local levels, in English and Nepali.
library;

export 'core.dart';
export 'src/rendering/asset_map_data_source.dart';
export 'src/rendering/style/nepal_map_theme.dart';
export 'src/rendering/style/region_style.dart';
export 'src/widget/nepal_map.dart';
export 'src/widget/nepal_map_breadcrumb.dart';
export 'src/widget/nepal_map_controller.dart'
    hide NepalMapControllerInternals, NepalMapDelegate;
export 'src/widget/region_tooltip.dart'
    show RegionTooltip, RegionTooltipBuilder;
