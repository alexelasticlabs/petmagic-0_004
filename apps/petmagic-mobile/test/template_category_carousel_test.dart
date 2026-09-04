import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/domain/template_discovery_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_category_carousel.dart';

void main() {
  testWidgets('category carousel advances automatically', (tester) async {
    await tester.pumpWidget(
      _carouselHost(autoAdvanceInterval: const Duration(milliseconds: 100)),
    );

    expect(_currentPage(tester), closeTo(1, 0.001));
    await tester.pump(const Duration(milliseconds: 101));
    await tester.pump(PetMagicMotion.slow);

    expect(_currentPage(tester), closeTo(2, 0.001));
    await _disposeCarousel(tester);
  });

  testWidgets('category carousel disables autoplay for reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _carouselHost(
        autoAdvanceInterval: const Duration(milliseconds: 100),
        disableAnimations: true,
      ),
    );

    await tester.pump(const Duration(seconds: 2));

    expect(_currentPage(tester), closeTo(1, 0.001));
    await _disposeCarousel(tester);
  });

  testWidgets('manual drag pauses category carousel autoplay', (tester) async {
    await tester.pumpWidget(
      _carouselHost(autoAdvanceInterval: const Duration(milliseconds: 100)),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('template-category-carousel')),
      ),
    );
    await gesture.moveBy(const Offset(-24, 0));
    await tester.pump();
    final heldPage = _currentPage(tester);

    await tester.pump(const Duration(seconds: 1));

    expect(_currentPage(tester), closeTo(heldPage, 0.001));
    await gesture.up();
    await tester.pump();
    await _disposeCarousel(tester);
  });

  testWidgets('adjacent category semantics action opens it directly', (
    tester,
  ) async {
    final openedCategories = <String>[];
    await tester.pumpWidget(
      _carouselHost(
        autoAdvanceInterval: const Duration(minutes: 1),
        onCategoryPressed: openedCategories.add,
      ),
    );
    final semantics = tester.ensureSemantics();

    try {
      final adjacentCategory = find.semantics.byLabel('Pet Mischief, 2 / 3');
      tester.semantics.performAction(adjacentCategory, SemanticsAction.tap);
      await tester.pump();

      expect(openedCategories, ['Pet Mischief']);
      expect(_currentPage(tester), closeTo(1, 0.001));
    } finally {
      semantics.dispose();
    }
    await _disposeCarousel(tester);
  });
}

Widget _carouselHost({
  required Duration autoAdvanceInterval,
  bool disableAnimations = false,
  ValueChanged<String> onCategoryPressed = _ignoreCategory,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        disableAnimations: disableAnimations,
      ),
      child: Scaffold(
        body: TemplateCategoryCarousel(
          sections: const [
            TemplateDiscoverySection(category: 'Funny', items: []),
            TemplateDiscoverySection(category: 'Pet Mischief', items: []),
            TemplateDiscoverySection(category: 'Pawsome Frames', items: []),
          ],
          eyebrowLabel: 'Discover',
          openLabel: 'Open',
          autoAdvanceInterval: autoAdvanceInterval,
          onCategoryPressed: onCategoryPressed,
        ),
      ),
    ),
  );
}

double _currentPage(WidgetTester tester) {
  final pageView = tester.widget<PageView>(
    find.byKey(const ValueKey('template-category-carousel')),
  );
  return pageView.controller!.page!;
}

Future<void> _disposeCarousel(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void _ignoreCategory(String _) {}
