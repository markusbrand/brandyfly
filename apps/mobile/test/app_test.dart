import 'package:brandyfly/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the application name', (tester) async {
    await tester.pumpWidget(const BrandyFlyApp());

    expect(find.text('BrandyFly'), findsOneWidget);
  });
}
