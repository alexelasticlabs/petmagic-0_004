import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/shared/widgets/horizontal_filter_strip.dart';

void main() {
  testWidgets(
    'keeps the first filter aligned and does not overlay either edge',
    (tester) async {
      const firstFilter = Key('first-filter');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: HorizontalFilterStrip(
                child: Row(
                  children: [
                    SizedBox(key: firstFilter, width: 80, height: 40),
                    SizedBox(width: 8),
                    SizedBox(width: 160, height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final filterStrip = find.byType(HorizontalFilterStrip);
      final scrollView = find.descendant(
        of: filterStrip,
        matching: find.byType(SingleChildScrollView),
      );

      expect(tester.getTopLeft(find.byKey(firstFilter)).dx, 18);
      expect(scrollView, findsOneWidget);
      expect(tester.widget<SingleChildScrollView>(scrollView).padding, isNull);
      expect(
        find.descendant(of: filterStrip, matching: find.byType(ShaderMask)),
        findsNothing,
      );
    },
  );
}
