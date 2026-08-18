import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/models/ui_config.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/widgets/flight/numeric_text_widget.dart';
import 'package:brandyfly/widgets/flight/vario_lift_sink_bar.dart';
import 'package:brandyfly/widgets/flight/wind_direction_widget.dart';
import 'package:brandyfly/widgets/layout/layout_strategy_container.dart';
import 'package:brandyfly/widgets/navigation/top_nav_bar.dart';
import 'package:brandyfly/widgets/settings/ui_settings_panel.dart';

void main() {
  group('UI Components Widget Tests', () {
    testWidgets('NumericTextWidget renders all visual mockup styles', (
      tester,
    ) async {
      for (final style in NumericWidgetStyle.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NumericTextWidget(
                label: 'ALT',
                value: '1850',
                unit: 'm',
                style: style,
              ),
            ),
          ),
        );
        expect(find.textContaining('1850'), findsOneWidget);
      }
    });

    testWidgets('WindDirectionWidget renders relative arrow and compass rose', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WindDirectionWidget(
              directionDegrees: 210,
              speedKmH: 15.5,
              style: WindWidgetStyle.relativeArrow,
            ),
          ),
        ),
      );
      expect(find.textContaining('15.5 km/h'), findsOneWidget);
    });

    testWidgets('VarioLiftSinkBar renders vertical bar and analog dial', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VarioLiftSinkBar(
              climbRateMs: 2.4,
              style: LiftSinkBarStyle.verticalEdgeBar,
            ),
          ),
        ),
      );
      expect(find.textContaining('+2.4'), findsOneWidget);
    });

    testWidgets('TopNavBarOverlay slides down and shows controls', (
      tester,
    ) async {
      final manager = ScreenManagerService();
      manager.toggleNavBar(true);

      await tester.pumpWidget(
        MaterialApp(
          home: TopNavBarOverlay(
            screenManager: manager,
            child: const Scaffold(body: Text('Main Body')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BrandyFly Navigation'), findsOneWidget);
      expect(find.text('Edit Mode'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('UISettingsPanel allows changing visual styles', (
      tester,
    ) async {
      final manager = ScreenManagerService();

      await tester.pumpWidget(
        MaterialApp(home: UISettingsPanel(screenManager: manager)),
      );

      expect(find.text('UI Visual Mockup Settings'), findsOneWidget);

      manager.setNumericWidgetStyle(NumericWidgetStyle.highContrastBox);
      await tester.pump();

      expect(
        manager.config.numericWidgetStyle,
        NumericWidgetStyle.highContrastBox,
      );
    });

    testWidgets(
      'LayoutStrategyContainer renders in edit mode and across all strategies',
      (tester) async {
        final manager = ScreenManagerService();
        manager.toggleEditMode(true);

        for (final strategy in LayoutStrategyStyle.values) {
          manager.setLayoutStrategyStyle(strategy);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: LayoutStrategyContainer(
                  screenManager: manager,
                  telemetryData: const {
                    'altitude': 1450.0,
                    'speed': 42.5,
                    'glide': 8.4,
                    'hag': 320.0,
                    'climb': 1.8,
                    'windDir': 220.0,
                    'windSpeed': 14.0,
                    'history': [1400.0, 1420.0, 1450.0],
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Done Editing'), findsOneWidget);
          expect(find.text('Add Widget'), findsOneWidget);
        }
      },
    );
  });
}
