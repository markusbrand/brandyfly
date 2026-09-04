## Why

The current flight screen layout engine uses a coarse 4-column grid with a hardcoded 90px minimum cell height floor, forcing widgets to take up at least 25% of screen width and preventing compact instrumentation. Pilots cannot scale instrument widgets down to create dense, customized flight computer layouts (such as multi-metric sidebars, compact top status bars, or small corner gauges alongside maps).

Upgrading to a high-resolution grid system (with 8 or 12 grid subdivisions, slim row heights, and responsive widget scaling) gives pilots fine-grained resizing control while preserving zero-dead-space telemetry readability.

## What Changes

- **High-Resolution Layout Grid**: Upgrade the grid resolution from 4 columns to an 8-column (or 12-column) grid coordinate space, allowing significantly smaller, more granular widget dimensions (e.g. 1/8th or 1/12th width increments).
- **Reduced Minimum Row Height & Adaptive Row Scaling**: Lower the minimum row height floor (from 90px to 36-40px) and support flexible row subdivision counts so compact numeric and status widgets can fit into slim bars without excessive vertical padding.
- **Backwards-Compatible Coordinate Migration**: Automatically scale or migrate existing 4-column widget coordinates (`x`, `y`, `w`, `h`) to the higher-resolution grid space so existing saved screen configurations do not break.
- **Streamlined Edit-Mode Controls for Compact Widgets**: Adapt the widget edit chrome (header and resize controls) so that small widgets (e.g., 1x1 or 2x1 on the high-res grid) remain fully manageable without control clipping or overcrowding.
- **Widget Content Scalability**: Ensure all widgets (numeric gauges, vario bar, wind arrow, sparkline chart, map) render legibly at smaller dimensions.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `screen-widget-configuration`: Upgrades screen layout grid resolution from 4 columns to a high-density 8-column coordinate space, lowers minimum cell height constraints to support compact sizing, and enhances edit-mode manipulation for compact instrument widgets.

## Impact

- **Affected Code**: `apps/mobile/lib/widgets/layout/layout_strategy_container.dart`, `apps/mobile/lib/services/screen_manager_service.dart`, `apps/mobile/lib/models/ui_config.dart`, and associated widget test suites.
- **Data / Persistence**: Saved UI configs and default screen presets will use the higher-resolution grid coordinates; automatic upscaling ensures backward compatibility with existing 4-column configurations.
- **Safety / Offline**: No impact on core offline vario/sensor pipelines. Layout remains local-first and high-performance.
