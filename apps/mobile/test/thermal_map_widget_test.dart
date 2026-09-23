import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:brandyfly/widgets/flight/thermal_map_widget.dart';
import 'package:brandyfly/models/ui_config.dart';

void main() {
  testWidgets('ThermalMapWidget renders default points without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: ThermalMapWidget(
            style: ThermalMapStyle.xctrackBubbles,
            showCore: true,
          ),
        ),
      ),
    ));

    // Wait for animations and render
    await tester.pump();
    
    // It should render CustomPaint
    expect(find.byType(CustomPaint), findsWidgets);
    
    // Find style badge
    expect(find.text('XCtrack Bubbles'), findsOneWidget);
    expect(find.text('GROUND'), findsOneWidget); // Default is Ground
  });
  
  testWidgets('ThermalMapWidget toggles airmass mode', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: ThermalMapWidget(
            style: ThermalMapStyle.xctrackBubbles,
            showCore: true,
          ),
        ),
      ),
    ));

    await tester.pump();
    expect(find.text('GROUND'), findsOneWidget);
    
    await tester.tap(find.text('GROUND'));
    await tester.pump();
    
    expect(find.text('AIRMASS'), findsOneWidget);
  });
}
