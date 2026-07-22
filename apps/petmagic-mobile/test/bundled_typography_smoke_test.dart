import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/app/theme/petmagic_typography.dart';

import 'widget_test_support.dart';

void main() {
  configureWidgetTestHarness();

  testWidgets('bundled Comfortaa and Material icons render together', (
    tester,
  ) async {
    const weights = <FontWeight>[
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              const Text('PetMagic Привет', key: Key('mixed_script_text')),
              for (final weight in weights)
                Text(
                  'Comfortaa ${weight.value}: Latin Кириллица',
                  key: Key('weight_${weight.value}'),
                  style: TextStyle(
                    fontFamily: PetMagicTypography.resolvedFontFamily,
                    fontWeight: weight,
                  ),
                ),
              const Icon(Icons.pets_rounded, key: Key('material_icon')),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final mixedText = tester.widget<Text>(
      find.byKey(const Key('mixed_script_text')),
    );
    final effectiveStyle = DefaultTextStyle.of(
      tester.element(find.byKey(const Key('mixed_script_text'))),
    ).style.merge(mixedText.style);

    expect(effectiveStyle.fontFamily, PetMagicTypography.resolvedFontFamily);
    for (final weight in weights) {
      final text = tester.widget<Text>(
        find.byKey(Key('weight_${weight.value}')),
      );
      expect(text.style?.fontFamily, PetMagicTypography.resolvedFontFamily);
      expect(text.style?.fontWeight, weight);
    }
    expect(Icons.pets_rounded.fontFamily, 'MaterialIcons');
    expect(find.text('PetMagic Привет'), findsOneWidget);
    expect(find.byIcon(Icons.pets_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
