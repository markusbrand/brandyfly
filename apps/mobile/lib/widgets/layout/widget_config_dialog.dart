import 'package:flutter/material.dart';
import '../../models/ui_config.dart';
import '../../services/screen_manager_service.dart';

void showWidgetConfigDialog(
  BuildContext context,
  WidgetPlacementModel model,
  ScreenManagerService screenManager,
) {
  int curX = model.x;
  int curY = model.y;
  int curW = model.w;
  int curH = model.h;

  NumericWidgetStyle curNumericStyle = model.effectiveNumericStyle;
  WindWidgetStyle curWindStyle = model.effectiveWindStyle;
  LiftSinkBarStyle curVarioStyle = model.effectiveVarioStyle;
  AltitudeChartStyle curAltitudeChartStyle =
      model.effectiveAltitudeChartStyle;
  MapWidgetStyle curMapStyle = model.effectiveMapStyle;
  MapOrientation curMapOrientation = model.effectiveMapOrientation;
  bool curMapAirspace = model.effectiveMapShowAirspace;
  bool curMapThermals = model.effectiveMapShowThermals;
  bool curMapTrack = model.effectiveMapShowTrack;
  bool curMapContours = model.effectiveMapShowContours;
  double curMapZoomLevel = model.effectiveMapZoomLevel;
  int curMapTrackHistoryMinutes = model.effectiveMapTrackHistoryMinutes;
  bool curMapTrackShowOlderTail = model.effectiveMapTrackShowOlderTail;
  ThermalMapStyle curThermalMapStyle = model.effectiveThermalMapStyle;
  bool curThermalMapShowCore = model.effectiveThermalMapShowCore;
  int curThermalMapHistorySeconds = model.effectiveThermalMapHistorySeconds;

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.blueGrey.shade900,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.tune, color: Colors.cyanAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Configure ${model.type.name.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Position and Dimensions
                    buildSectionTitle('Position & Size'),
                    Card(
                      color: Colors.black38,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Position X:',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove,
                                        size: 18,
                                      ),
                                      tooltip: 'Decrease X position',
                                      onPressed: curX > 0
                                          ? () => setDialogState(() => curX--)
                                          : null,
                                    ),
                                    Text(
                                      '$curX',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 18),
                                      tooltip: 'Increase X position',
                                      onPressed: curX + curW < 8
                                          ? () => setDialogState(() => curX++)
                                          : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Position Y:',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove,
                                        size: 18,
                                      ),
                                      tooltip: 'Decrease Y position',
                                      onPressed: curY > 0
                                          ? () => setDialogState(() => curY--)
                                          : null,
                                    ),
                                    Text(
                                      '$curY',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 18),
                                      tooltip: 'Increase Y position',
                                      onPressed: () =>
                                          setDialogState(() => curY++),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Width:',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove,
                                        size: 18,
                                      ),
                                      tooltip: 'Decrease width',
                                      onPressed: curW > 1
                                          ? () => setDialogState(() => curW--)
                                          : null,
                                    ),
                                    Text(
                                      '$curW',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 18),
                                      tooltip: 'Increase width',
                                      onPressed: curX + curW < 8
                                          ? () => setDialogState(() => curW++)
                                          : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Height:',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove,
                                        size: 18,
                                      ),
                                      tooltip: 'Decrease height',
                                      onPressed: curH > 1
                                          ? () => setDialogState(() => curH--)
                                          : null,
                                    ),
                                    Text(
                                      '$curH',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 18),
                                      tooltip: 'Increase height',
                                      onPressed: curH < 16
                                          ? () => setDialogState(() => curH++)
                                          : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Section 2: Widget-specific configuration
                    if (model.type == WidgetType.altitude ||
                        model.type == WidgetType.speed ||
                        model.type == WidgetType.glide ||
                        model.type == WidgetType.hag) ...[
                      buildSectionTitle('Numeric Display Style'),
                      Card(
                        color: Colors.black38,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              styleChip<NumericWidgetStyle>(
                                label: 'Minimalist',
                                value: NumericWidgetStyle.minimalistText,
                                selectedValue: curNumericStyle,
                                onSelected: (val) => setDialogState(
                                  () => curNumericStyle = val,
                                ),
                              ),
                              styleChip<NumericWidgetStyle>(
                                label: 'High Contrast',
                                value: NumericWidgetStyle.highContrastBox,
                                selectedValue: curNumericStyle,
                                onSelected: (val) => setDialogState(
                                  () => curNumericStyle = val,
                                ),
                              ),
                              styleChip<NumericWidgetStyle>(
                                label: 'Circular Gauge',
                                value: NumericWidgetStyle.circularGauge,
                                selectedValue: curNumericStyle,
                                onSelected: (val) => setDialogState(
                                  () => curNumericStyle = val,
                                ),
                              ),
                              styleChip<NumericWidgetStyle>(
                                label: 'Retro Digital',
                                value: NumericWidgetStyle.retroDigital,
                                selectedValue: curNumericStyle,
                                onSelected: (val) => setDialogState(
                                  () => curNumericStyle = val,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else if (model.type == WidgetType.windDirection) ...[
                      buildSectionTitle('Wind Widget Style'),
                      Card(
                        color: Colors.black38,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              styleChip<WindWidgetStyle>(
                                label: 'Relative Arrow',
                                value: WindWidgetStyle.relativeArrow,
                                selectedValue: curWindStyle,
                                onSelected: (val) =>
                                    setDialogState(() => curWindStyle = val),
                              ),
                              styleChip<WindWidgetStyle>(
                                label: 'Compass Rose',
                                value: WindWidgetStyle.miniCompassRose,
                                selectedValue: curWindStyle,
                                onSelected: (val) =>
                                    setDialogState(() => curWindStyle = val),
                              ),
                              styleChip<WindWidgetStyle>(
                                label: 'Windsock',
                                value: WindWidgetStyle.windsockIndicator,
                                selectedValue: curWindStyle,
                                onSelected: (val) =>
                                    setDialogState(() => curWindStyle = val),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else if (model.type == WidgetType.varioBar) ...[
                      buildSectionTitle('Vario Bar Style'),
                      Card(
                        color: Colors.black38,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              styleChip<LiftSinkBarStyle>(
                                label: 'Vertical Edge Bar',
                                value: LiftSinkBarStyle.verticalEdgeBar,
                                selectedValue: curVarioStyle,
                                onSelected: (val) =>
                                    setDialogState(() => curVarioStyle = val),
                              ),
                              styleChip<LiftSinkBarStyle>(
                                label: 'Analog Dial',
                                value: LiftSinkBarStyle.analogDial,
                                selectedValue: curVarioStyle,
                                onSelected: (val) =>
                                    setDialogState(() => curVarioStyle = val),
                              ),
                              styleChip<LiftSinkBarStyle>(
                                label: 'Edge Glow',
                                value: LiftSinkBarStyle.screenEdgeGlow,
                                selectedValue: curVarioStyle,
                                onSelected: (val) =>
                                    setDialogState(() => curVarioStyle = val),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else if (model.type == WidgetType.altitudeChart) ...[
                      buildSectionTitle('Altitude Chart Style'),
                      Card(
                        color: Colors.black38,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              styleChip<AltitudeChartStyle>(
                                label: 'Sparkline',
                                value: AltitudeChartStyle.minimalSparkline,
                                selectedValue: curAltitudeChartStyle,
                                onSelected: (val) => setDialogState(
                                  () => curAltitudeChartStyle = val,
                                ),
                              ),
                              styleChip<AltitudeChartStyle>(
                                label: 'Filled Area',
                                value: AltitudeChartStyle.filledAreaGraph,
                                selectedValue: curAltitudeChartStyle,
                                onSelected: (val) => setDialogState(
                                  () => curAltitudeChartStyle = val,
                                ),
                              ),
                              styleChip<AltitudeChartStyle>(
                                label: 'Detailed Grid',
                                value: AltitudeChartStyle.detailedGrid,
                                selectedValue: curAltitudeChartStyle,
                                onSelected: (val) => setDialogState(
                                  () => curAltitudeChartStyle = val,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else if (model.type == WidgetType.map) ...[
                      buildSectionTitle('Map Style'),
                      Card(
                        color: Colors.black38,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              styleChip<MapWidgetStyle>(
                                label: 'Alpine Topo',
                                value: MapWidgetStyle.topoContours,
                                selectedValue: curMapStyle,
                                onSelected: (val) =>
                                    setDialogState(() => curMapStyle = val),
                              ),
                              styleChip<MapWidgetStyle>(
                                label: 'Vector HUD',
                                value: MapWidgetStyle.minimalVector,
                                selectedValue: curMapStyle,
                                onSelected: (val) =>
                                    setDialogState(() => curMapStyle = val),
                              ),
                              styleChip<MapWidgetStyle>(
                                label: 'Thermal Radar',
                                value: MapWidgetStyle.thermalHeatmap,
                                selectedValue: curMapStyle,
                                onSelected: (val) =>
                                    setDialogState(() => curMapStyle = val),
                              ),
                              styleChip<MapWidgetStyle>(
                                label: 'Shaded Relief',
                                value: MapWidgetStyle.satelliteTerrain,
                                selectedValue: curMapStyle,
                                onSelected: (val) =>
                                    setDialogState(() => curMapStyle = val),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      buildSectionTitle('Initial Zoom Level'),
                      Card(
                        color: Colors.black38,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Zoom: ${curMapZoomLevel.toStringAsFixed(1)}x',
                                    style: const TextStyle(
                                      color: Colors.cyanAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        key: const Key(
                                          'btn_config_zoom_decrease',
                                        ),
                                        icon: const Icon(
                                          Icons.remove,
                                          size: 18,
                                        ),
                                        tooltip: 'Decrease map zoom',
                                        onPressed: curMapZoomLevel > 3.0
                                            ? () => setDialogState(
                                                () => curMapZoomLevel =
                                                    (curMapZoomLevel - 0.5)
                                                        .clamp(3.0, 18.0),
                                              )
                                            : null,
                                      ),
                                      IconButton(
                                        key: const Key(
                                          'btn_config_zoom_increase',
                                        ),
                                        icon: const Icon(Icons.add, size: 18),
                                        tooltip: 'Increase map zoom',
                                        onPressed: curMapZoomLevel < 18.0
                                            ? () => setDialogState(
                                                () => curMapZoomLevel =
                                                    (curMapZoomLevel + 0.5)
                                                        .clamp(3.0, 18.0),
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Slider(
                                key: const Key('slider_config_zoom'),
                                value: curMapZoomLevel.clamp(3.0, 18.0),
                                min: 3.0,
                                max: 18.0,
                                divisions: 30,
                                label:
                                    '${curMapZoomLevel.toStringAsFixed(1)}x',
                                activeColor: Colors.cyanAccent,
                                onChanged: (val) => setDialogState(
                                  () => curMapZoomLevel = val,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Presets:',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  ActionChip(
                                    label: const Text(
                                      'Overview (10.0x)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    backgroundColor: Colors.black45,
                                    onPressed: () => setDialogState(
                                      () => curMapZoomLevel = 10.0,
                                    ),
                                  ),
                                  ActionChip(
                                    label: const Text(
                                      'XC Cruise (13.5x)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    backgroundColor: Colors.black45,
                                    onPressed: () => setDialogState(
                                      () => curMapZoomLevel = 13.5,
                                    ),
                                  ),
                                  ActionChip(
                                    label: const Text(
                                      'Thermal (15.5x)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    backgroundColor: Colors.black45,
                                    onPressed: () => setDialogState(
                                      () => curMapZoomLevel = 15.5,
                                    ),
                                  ),
                                  ActionChip(
                                    label: const Text(
                                      'LZ Final (16.5x)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    backgroundColor: Colors.black45,
                                    onPressed: () => setDialogState(
                                      () => curMapZoomLevel = 16.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      buildSectionTitle('Map Orientation'),
                      Card(
                        color: Colors.black38,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              styleChip<MapOrientation>(
                                label: 'Track Up',
                                value: MapOrientation.trackUp,
                                selectedValue: curMapOrientation,
                                onSelected: (val) => setDialogState(
                                  () => curMapOrientation = val,
                                ),
                              ),
                              styleChip<MapOrientation>(
                                label: 'North Up',
                                value: MapOrientation.northUp,
                                selectedValue: curMapOrientation,
                                onSelected: (val) => setDialogState(
                                  () => curMapOrientation = val,
                                ),
                              ),
                              styleChip<MapOrientation>(
                                label: 'Heading Up',
                                value: MapOrientation.headingUp,
                                selectedValue: curMapOrientation,
                                onSelected: (val) => setDialogState(
                                  () => curMapOrientation = val,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      buildSectionTitle('Map Layer Overlays'),
                      Card(
                        color: Colors.black38,
                        child: Column(
                          children: [
                            SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              title: const Text(
                                'Airspaces (CTR / TMA)',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              value: curMapAirspace,
                              activeThumbColor: Colors.cyanAccent,
                              onChanged: (val) =>
                                  setDialogState(() => curMapAirspace = val),
                            ),
                            SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              title: const Text(
                                'Thermal Updraft Hotspots',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              value: curMapThermals,
                              activeThumbColor: Colors.cyanAccent,
                              onChanged: (val) =>
                                  setDialogState(() => curMapThermals = val),
                            ),
                            SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              title: const Text(
                                'Flight Trail / Breadcrumbs',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              value: curMapTrack,
                              activeThumbColor: Colors.cyanAccent,
                              onChanged: (val) =>
                                  setDialogState(() => curMapTrack = val),
                            ),
                            SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              title: const Text(
                                'Topographic Contours',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              value: curMapContours,
                              activeThumbColor: Colors.cyanAccent,
                              onChanged: (val) =>
                                  setDialogState(() => curMapContours = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      buildSectionTitle('Track Visualization'),
                      Card(
                        color: Colors.black38,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Track History Window',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  durationChip(
                                    2,
                                    curMapTrackHistoryMinutes,
                                    setDialogState,
                                    (v) {
                                      curMapTrackHistoryMinutes = v;
                                    },
                                  ),
                                  durationChip(
                                    5,
                                    curMapTrackHistoryMinutes,
                                    setDialogState,
                                    (v) {
                                      curMapTrackHistoryMinutes = v;
                                    },
                                  ),
                                  durationChip(
                                    10,
                                    curMapTrackHistoryMinutes,
                                    setDialogState,
                                    (v) {
                                      curMapTrackHistoryMinutes = v;
                                    },
                                  ),
                                  durationChip(
                                    15,
                                    curMapTrackHistoryMinutes,
                                    setDialogState,
                                    (v) {
                                      curMapTrackHistoryMinutes = v;
                                    },
                                  ),
                                  durationChip(
                                    30,
                                    curMapTrackHistoryMinutes,
                                    setDialogState,
                                    (v) {
                                      curMapTrackHistoryMinutes = v;
                                    },
                                  ),
                                  durationChip(
                                    0,
                                    curMapTrackHistoryMinutes,
                                    setDialogState,
                                    (v) {
                                      curMapTrackHistoryMinutes = v;
                                    },
                                    label: 'All',
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white12),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Show Older Tail',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Muted faded trail behind the active window',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                                value: curMapTrackShowOlderTail,
                                activeThumbColor: Colors.cyanAccent,
                                onChanged: (val) => setDialogState(
                                  () => curMapTrackShowOlderTail = val,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else if (model.type == WidgetType.thermalMap) ...[
                      buildSectionTitle('Thermal Map Visual Style'),
                      Card(
                        color: Colors.black38,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              styleChip<ThermalMapStyle>(
                                label: 'Option 1: XCtrack Bubbles',
                                value: ThermalMapStyle.xctrackBubbles,
                                selectedValue: curThermalMapStyle,
                                onSelected: (val) => setDialogState(
                                  () => curThermalMapStyle = val,
                                ),
                              ),
                              styleChip<ThermalMapStyle>(
                                label: 'Option 2: Burnair Core Assist',
                                value: ThermalMapStyle.burnairCore,
                                selectedValue: curThermalMapStyle,
                                onSelected: (val) => setDialogState(
                                  () => curThermalMapStyle = val,
                                ),
                              ),
                              styleChip<ThermalMapStyle>(
                                label: 'Option 3: Navigator Ribbon',
                                value: ThermalMapStyle.navigatorRibbon,
                                selectedValue: curThermalMapStyle,
                                onSelected: (val) => setDialogState(
                                  () => curThermalMapStyle = val,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      buildSectionTitle('Thermal Core Display'),
                      Card(
                        color: Colors.black38,
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          title: const Text(
                            'Show Thermal Core Center & Drift',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: const Text(
                            'Draws estimated lift core centroid with wind vector',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                          value: curThermalMapShowCore,
                          activeThumbColor: Colors.cyanAccent,
                          onChanged: (val) => setDialogState(
                            () => curThermalMapShowCore = val,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan.shade700,
                ),
                onPressed: () {
                  final updated = model.copyWith(
                    x: curX,
                    y: curY,
                    w: curW,
                    h: curH,
                    numericStyle: curNumericStyle,
                    windStyle: curWindStyle,
                    varioStyle: curVarioStyle,
                    altitudeChartStyle: curAltitudeChartStyle,
                    mapStyle: curMapStyle,
                    mapOrientation: curMapOrientation,
                    mapShowAirspace: curMapAirspace,
                    mapShowThermals: curMapThermals,
                    mapShowTrack: curMapTrack,
                    mapShowContours: curMapContours,
                    mapZoomLevel: curMapZoomLevel,
                    mapTrackHistoryMinutes: curMapTrackHistoryMinutes,
                    mapTrackShowOlderTail: curMapTrackShowOlderTail,
                    thermalMapStyle: curThermalMapStyle,
                    thermalMapShowCore: curThermalMapShowCore,
                    thermalMapHistorySeconds: curThermalMapHistorySeconds,
                  );
                  screenManager.updateWidgetPlacement(updated);
                  Navigator.pop(ctx);
                },
                child: const Text(
                  'Apply',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget buildSectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 4, top: 4),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Colors.cyanAccent,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    ),
  );
}

Widget styleChip<T>({
  required String label,
  required T value,
  required T selectedValue,
  required ValueChanged<T> onSelected,
}) {
  final isSelected = value == selectedValue;
  return ChoiceChip(
    label: Text(label),
    selected: isSelected,
    selectedColor: Colors.cyan.shade800,
    backgroundColor: Colors.black54,
    labelStyle: TextStyle(
      color: isSelected ? Colors.white : Colors.white70,
      fontSize: 11,
      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
    ),
    onSelected: (sel) {
      if (sel) onSelected(value);
    },
  );
}

Widget durationChip(
  int value,
  int currentValue,
  StateSetter setDialogState,
  ValueChanged<int> onChanged, {
  String? label,
}) {
  final isSelected = value == currentValue;
  return ChoiceChip(
    label: Text(label ?? '${value}m'),
    selected: isSelected,
    selectedColor: Colors.cyan.shade800,
    backgroundColor: Colors.black54,
    labelStyle: TextStyle(
      color: isSelected ? Colors.white : Colors.white70,
      fontSize: 11,
      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
    ),
    onSelected: (sel) {
      if (sel) {
        setDialogState(() => onChanged(value));
      }
    },
  );
}
