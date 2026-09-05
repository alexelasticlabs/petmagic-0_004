import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/domain/template_discovery_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_category_carousel.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_discovery_media.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  testWidgets(
    'large text widens the carousel without resetting the selection',
    (tester) async {
      await tester.pumpWidget(
        _carouselHost(autoAdvanceInterval: const Duration(minutes: 1)),
      );
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(_currentPage(tester), closeTo(2, 0.001));
      await tester.pumpWidget(
        _carouselHost(
          autoAdvanceInterval: const Duration(minutes: 1),
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PageView>(find.byType(PageView))
            .controller!
            .viewportFraction,
        0.88,
      );
      expect(_currentPage(tester), closeTo(2, 0.001));
      expect(tester.takeException(), isNull);
      await _disposeCarousel(tester);
    },
  );

  testWidgets('disabled autoplay still allows manual category swipes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _carouselHost(
        autoAdvanceInterval: const Duration(seconds: 5),
        autoplayEnabled: false,
      ),
    );
    await tester.pump(const Duration(seconds: 30));
    expect(_currentPage(tester), closeTo(1, 0.001));
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(_currentPage(tester), closeTo(2, 0.001));
    await _disposeCarousel(tester);
  });

  testWidgets(
    'configured interval replaces default and disabling cancels its timer',
    (tester) async {
      await tester.pumpWidget(
        _carouselHost(autoAdvanceInterval: const Duration(seconds: 12)),
      );
      await tester.pump(const Duration(seconds: 11));
      expect(_currentPage(tester), closeTo(1, 0.001));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(PetMagicMotion.slow);
      expect(_currentPage(tester), closeTo(2, 0.001));
      await tester.pumpWidget(
        _carouselHost(
          autoAdvanceInterval: const Duration(seconds: 12),
          autoplayEnabled: false,
        ),
      );
      await tester.pump(const Duration(seconds: 30));
      expect(_currentPage(tester), closeTo(2, 0.001));
      await _disposeCarousel(tester);
    },
  );

  late Duration visibilityInterval;
  setUp(() {
    visibilityInterval = VisibilityDetectorController.instance.updateInterval;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });
  tearDown(() {
    VisibilityDetectorController.instance.updateInterval = visibilityInterval;
  });

  testWidgets('offscreen carousel pauses autoplay and resumes when visible', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      _carouselHost(
        autoAdvanceInterval: const Duration(milliseconds: 100),
        scrollController: scrollController,
      ),
    );
    scrollController.jumpTo(600);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(_currentPage(tester), closeTo(1, 0.001));

    scrollController.jumpTo(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 101));
    await tester.pump(PetMagicMotion.slow);
    expect(_currentPage(tester), closeTo(2, 0.001));
    await _disposeCarousel(tester);
  });

  testWidgets('parallax moves only media paint while preserving its state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _carouselHost(autoAdvanceInterval: const Duration(minutes: 1)),
    );
    final parallax = find.byKey(const ValueKey('discovery-parallax-1'));
    final media = find.descendant(
      of: parallax,
      matching: find.byType(TemplateDiscoveryMedia),
    );
    final originalMediaState = tester.state(media);
    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('template-category-carousel')),
      ),
    );
    await gesture.moveBy(const Offset(-75, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-50, 0));
    await tester.pump();
    final transform = tester.widget<Transform>(parallax).transform;
    expect(transform.storage[12].abs(), greaterThan(0));
    expect(tester.state(media), same(originalMediaState));
    await gesture.up();
    await tester.pumpAndSettle();
    await _disposeCarousel(tester);
  });

  testWidgets('reduced motion leaves media untransformed during a drag', (
    tester,
  ) async {
    await tester.pumpWidget(
      _carouselHost(
        autoAdvanceInterval: const Duration(minutes: 1),
        disableAnimations: true,
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('template-category-carousel')),
      ),
    );
    await gesture.moveBy(const Offset(-75, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-50, 0));
    await tester.pump();
    final transform = tester
        .widget<Transform>(find.byKey(const ValueKey('discovery-parallax-1')))
        .transform;
    expect(transform.storage[12], 0);
    await gesture.up();
    await tester.pumpAndSettle();
    await _disposeCarousel(tester);
  });

  testWidgets(
    'position semantics selects categories and announces their name',
    (tester) async {
      final changed = <int>[];
      await tester.pumpWidget(
        _carouselHost(
          autoAdvanceInterval: const Duration(minutes: 1),
          onActiveCategoryChanged: changed.add,
        ),
      );
      final semantics = tester.ensureSemantics();
      final position = find.byKey(
        const ValueKey('discovery-carousel-position'),
      );
      final node = tester.getSemantics(position);
      expect(node.value, 'Funny, 1 / 3');
      tester.semantics.performAction(
        find.semantics.byLabel('Discover'),
        SemanticsAction.increase,
      );
      await tester.pumpAndSettle();
      expect(tester.getSemantics(position).value, 'Pet Mischief, 2 / 3');
      expect(changed, [0, 1]);
      semantics.dispose();
      await _disposeCarousel(tester);
    },
  );

  testWidgets('keyboard selects a category and opens the focused selection', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      _carouselHost(
        autoAdvanceInterval: const Duration(minutes: 1),
        onCategoryPressed: opened.add,
      ),
    );
    Focus.of(tester.element(find.byType(PageView))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_currentPage(tester), closeTo(2, 0.001));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(opened, ['Pet Mischief']);
    await _disposeCarousel(tester);
  });

  testWidgets('keyboard follows reading direction and pauses autoplay', (
    tester,
  ) async {
    await tester.pumpWidget(
      _carouselHost(
        autoAdvanceInterval: const Duration(milliseconds: 100),
        textDirection: TextDirection.rtl,
      ),
    );
    Focus.of(tester.element(find.byType(PageView))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_currentPage(tester), closeTo(3, 0.001));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(PetMagicMotion.slow);
    expect(_currentPage(tester), closeTo(3, 0.001));
    await _disposeCarousel(tester);
  });

  testWidgets('new categories reset active callback after layout', (
    tester,
  ) async {
    final changed = <int>[];
    final opened = <String>[];
    await tester.pumpWidget(
      _carouselHost(
        autoAdvanceInterval: const Duration(minutes: 1),
        onActiveCategoryChanged: changed.add,
      ),
    );
    Focus.of(tester.element(find.byType(PageView))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(changed, [0, 1]);

    await tester.pumpWidget(
      _carouselHost(
        autoAdvanceInterval: const Duration(minutes: 1),
        onActiveCategoryChanged: changed.add,
        onCategoryPressed: opened.add,
        sections: const [
          TemplateDiscoverySection(category: 'New collection', items: []),
        ],
      ),
    );
    await tester.pump();
    expect(changed, [0, 1, 0]);
    expect(_currentPage(tester), closeTo(0, 0.001));
    expect(
      find.byKey(const ValueKey('discovery-carousel-position')),
      findsNothing,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(opened, ['New collection']);
    expect(tester.takeException(), isNull);
    await _disposeCarousel(tester);
  });

  testWidgets('remount reports its initial active category exactly once', (
    tester,
  ) async {
    final changed = <int>[];
    Widget host() => _carouselHost(
      autoAdvanceInterval: const Duration(minutes: 1),
      onActiveCategoryChanged: changed.add,
    );
    await tester.pumpWidget(host());
    expect(changed, [0]);
    Focus.of(tester.element(find.byType(PageView))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(changed, [0, 1]);

    await _disposeCarousel(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(changed, [0, 1, 0]);
    expect(_currentPage(tester), closeTo(1, 0.001));
    await _disposeCarousel(tester);
  });

  testWidgets('loop waits for the gesture to finish before normalizing', (
    tester,
  ) async {
    final changed = <int>[];
    await tester.pumpWidget(
      _carouselHost(
        autoAdvanceInterval: const Duration(minutes: 1),
        onActiveCategoryChanged: changed.add,
      ),
    );
    final carousel = find.byKey(const ValueKey('template-category-carousel'));
    final width = tester.getSize(carousel).width * 0.58;
    final gesture = await tester.startGesture(tester.getCenter(carousel));
    await gesture.moveBy(const Offset(24, 0));
    await tester.pump();
    await gesture.moveBy(Offset(width * 0.75, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_currentPage(tester), inExclusiveRange(0, 0.5));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_currentPage(tester), closeTo(3, 0.001));
    expect(changed, [0, 2]);
    await _disposeCarousel(tester);
  });

  for (final width in [320.0, 390.0, 800.0]) {
    testWidgets('spotlight stays 2:3 at width $width and large text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _carouselHost(
          autoAdvanceInterval: const Duration(minutes: 1),
          disableAnimations: true,
          textScaler: const TextScaler.linear(2),
        ),
      );
      final size = tester.getSize(
        find.byKey(const ValueKey('discovery-category-Funny')).first,
      );
      expect(size.width / size.height, closeTo(2 / 3, 0.001));
      expect(tester.takeException(), isNull);
      await _disposeCarousel(tester);
    });
  }
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
  bool autoplayEnabled = true,
  TextScaler textScaler = TextScaler.noScaling,
  ValueChanged<String> onCategoryPressed = _ignoreCategory,
  ValueChanged<int>? onActiveCategoryChanged,
  ScrollController? scrollController,
  TextDirection textDirection = TextDirection.ltr,
  List<TemplateDiscoverySection> sections = const [
    TemplateDiscoverySection(category: 'Funny', items: []),
    TemplateDiscoverySection(category: 'Pet Mischief', items: []),
    TemplateDiscoverySection(category: 'Pawsome Frames', items: []),
  ],
}) {
  final carousel = TemplateCategoryCarousel(
    sections: sections,
    eyebrowLabel: 'Discover',
    openLabel: 'Open',
    autoAdvanceInterval: autoAdvanceInterval,
    autoplayEnabled: autoplayEnabled,
    onCategoryPressed: onCategoryPressed,
    onActiveCategoryChanged: onActiveCategoryChanged,
  );
  return MaterialApp(
    theme: AppTheme.light(),
    builder: (context, child) =>
        Directionality(textDirection: textDirection, child: child!),
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        disableAnimations: disableAnimations,
        textScaler: textScaler,
      ),
      child: Scaffold(
        body: scrollController == null
            ? carousel
            : SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  children: [carousel, const SizedBox(height: 1000)],
                ),
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
