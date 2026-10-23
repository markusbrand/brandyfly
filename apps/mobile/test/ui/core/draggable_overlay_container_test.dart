import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/ui/core/widgets/draggable_overlay_container.dart';

void main() {
  group('DraggableOverlayContainer', () {
    testWidgets('renders at initialAlignment without intercepting outside touches',
        (tester) async {
      bool backgroundTapped = false;
      bool cardTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    key: const Key('background_area'),
                    onTap: () => backgroundTapped = true,
                    child: Container(color: Colors.black),
                  ),
                ),
                DraggableOverlayContainer(
                  cardKey: const Key('test_overlay_card'),
                  initialAlignment: Alignment.topRight,
                  margin: const EdgeInsets.all(8),
                  child: GestureDetector(
                    key: const Key('card_content'),
                    onTap: () => cardTapped = true,
                    child: Container(
                      width: 100,
                      height: 50,
                      color: Colors.red,
                      child: const Text('Overlay'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final cardFinder = find.byKey(const Key('test_overlay_card'));
      expect(cardFinder, findsOneWidget);

      final initialTopRight = tester.getTopRight(cardFinder);
      expect(initialTopRight.dx, equals(800 - 8));
      expect(initialTopRight.dy, equals(8));

      // Tap background outside overlay
      await tester.tapAt(const Offset(100, 100));
      await tester.pump();
      expect(backgroundTapped, isTrue);
      expect(cardTapped, isFalse);

      // Tap inside overlay
      await tester.tap(find.byKey(const Key('card_content')));
      await tester.pump();
      expect(cardTapped, isTrue);
    });

    testWidgets('tracks 2D dragging and clamps to viewport safe-area boundaries',
        (tester) async {
      Offset? lastOffset;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 600),
              padding: EdgeInsets.only(top: 20, left: 10, right: 10, bottom: 20),
            ),
            child: Scaffold(
              body: DraggableOverlayContainer(
                cardKey: const Key('test_overlay_card'),
                initialAlignment: Alignment.topRight,
                margin: const EdgeInsets.all(5),
                onPositionChanged: (pos) => lastOffset = pos,
                child: Container(
                  width: 100,
                  height: 50,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        ),
      );

      final cardFinder = find.byKey(const Key('test_overlay_card'));

      // Drag into middle of screen
      await tester.drag(cardFinder, const Offset(-300, 200));
      await tester.pump();

      expect(lastOffset, isNotNull);
      expect(lastOffset!.dx, greaterThan(100));
      expect(lastOffset!.dy, greaterThan(100));

      // Drag way beyond top-left boundary
      await tester.drag(cardFinder, const Offset(-1000, -1000));
      await tester.pump();

      // Should clamp to minX = padding.left (10) + margin.left (5) = 15
      // and minY = padding.top (20) + margin.top (5) = 25
      final clampedTopLeft = tester.getTopLeft(cardFinder);
      expect(clampedTopLeft.dx, equals(15));
      expect(clampedTopLeft.dy, equals(25));

      // Drag way beyond bottom-right boundary
      await tester.drag(cardFinder, const Offset(2000, 2000));
      await tester.pump();

      // maxX = 800 - 100(width) - 10(safePadding.right) - 5(margin.right) = 685
      // maxY = 600 - 50(height) - 20(safePadding.bottom) - 5(margin.bottom) = 525
      final clampedBottomRight = tester.getBottomRight(cardFinder);
      expect(clampedBottomRight.dx, equals(800 - 15));
      expect(clampedBottomRight.dy, equals(600 - 25));
    });

    testWidgets('dynamically re-clamps position when child expands near edge',
        (tester) async {
      final isExpanded = ValueNotifier<bool>(false);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 600),
              padding: EdgeInsets.zero,
            ),
            child: Scaffold(
              body: DraggableOverlayContainer(
                cardKey: const Key('test_overlay_card'),
                initialPosition: const Offset(700, 500),
                margin: EdgeInsets.zero,
                child: ValueListenableBuilder<bool>(
                  valueListenable: isExpanded,
                  builder: (context, expanded, _) {
                    return Container(
                      width: expanded ? 300 : 100,
                      height: expanded ? 200 : 50,
                      color: Colors.green,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      final cardFinder = find.byKey(const Key('test_overlay_card'));
      expect(tester.getTopLeft(cardFinder), equals(const Offset(700, 500)));

      // Trigger expansion
      isExpanded.value = true;
      await tester.pumpAndSettle();

      // Expanded size is 300x200.
      // If position remained (700, 500), bottomRight would be (1000, 700), overflowing 800x600.
      // Clamped position must be (800 - 300, 600 - 200) = (500, 400).
      expect(tester.getTopLeft(cardFinder), equals(const Offset(500, 400)));
      expect(tester.getBottomRight(cardFinder), equals(const Offset(800, 600)));
    });

    testWidgets('controlled position updates and resets correctly',
        (tester) async {
      final controlledPos = ValueNotifier<Offset?>(const Offset(100, 100));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<Offset?>(
              valueListenable: controlledPos,
              builder: (context, pos, _) {
                return DraggableOverlayContainer(
                  cardKey: const Key('test_overlay_card'),
                  position: pos,
                  initialAlignment: Alignment.topRight,
                  margin: EdgeInsets.zero,
                  child: const SizedBox(width: 50, height: 50),
                );
              },
            ),
          ),
        ),
      );

      final cardFinder = find.byKey(const Key('test_overlay_card'));
      expect(tester.getTopLeft(cardFinder), equals(const Offset(100, 100)));

      // Move via controlled prop
      controlledPos.value = const Offset(200, 300);
      await tester.pump();
      expect(tester.getTopLeft(cardFinder), equals(const Offset(200, 300)));

      // Reset to null -> should fallback to initialAlignment (topRight: 800 - 50 = 750, 0)
      controlledPos.value = null;
      await tester.pump();
      expect(tester.getTopLeft(cardFinder), equals(const Offset(750, 0)));
    });
  });
}
