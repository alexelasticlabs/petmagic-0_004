import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/discovery_rail_navigation.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/discovery_section_reveal.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/discovery_snap_physics.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_discovery_rail.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_feed_playback_manager.dart';
import 'package:petmagic_mobile/features/templates/domain/template_discovery_models.dart';

import 'template_card_test_support.dart';

void main() {
  testWidgets(
    'rail remembers its horizontal position after leaving the viewport',
    (tester) async {
      final show = ValueNotifier(true);
      final bucket = PageStorageBucket();
      final manager = TemplateFeedPlaybackManager();
      addTearDown(show.dispose);
      addTearDown(manager.dispose);
      final section = TemplateDiscoverySection(
        category: 'Funny',
        items: List.generate(8, (index) => imageTemplate(id: 'card-$index')),
      );
      await tester.pumpWidget(
        _host(
          PageStorage(
            bucket: bucket,
            child: ValueListenableBuilder(
              valueListenable: show,
              builder: (_, visible, _) => visible
                  ? SizedBox(
                      width: 320,
                      child: TemplateDiscoveryRail(
                        section: section,
                        sectionIndex: 0,
                        moreLabel: 'Смотреть все',
                        onMorePressed: () {},
                        onTemplatePressed: (_) {},
                        playbackManager: manager,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      );
      final rail = find.byKey(const ValueKey('discovery-rail-Funny'));
      final scroll = find.descendant(
        of: rail,
        matching: find.byType(Scrollable),
      );
      await tester.drag(rail, const Offset(-220, 0));
      await tester.pumpAndSettle();
      final offset = tester.state<ScrollableState>(scroll).position.pixels;
      expect(offset, greaterThan(0));
      show.value = false;
      await tester.pump();
      expect(rail, findsNothing);
      show.value = true;
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scroll).position.pixels,
        closeTo(offset, 0.01),
      );
    },
  );

  testWidgets('large category headings keep width and a 48dp action', (
    tester,
  ) async {
    final manager = TemplateFeedPlaybackManager();
    addTearDown(manager.dispose);
    const category = 'Приключения домашних питомцев';
    var opened = false;
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 320,
          child: TemplateDiscoveryRail(
            section: TemplateDiscoverySection(
              category: category,
              items: [imageTemplate(id: 'one')],
            ),
            sectionIndex: 0,
            moreLabel: 'Смотреть все',
            onMorePressed: () => opened = true,
            onTemplatePressed: (_) {},
            playbackManager: manager,
          ),
        ),
        scale: 2,
      ),
    );
    final heading = find.text(category);
    final action = find.byKey(const ValueKey('discovery-more-$category'));
    expect(tester.widget<Text>(heading).maxLines, 2);
    expect(tester.getSize(heading).width, greaterThan(220));
    expect(tester.getSize(action).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    expect(find.text('Смотреть все'), findsNothing);
    await tester.tap(action);
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short rail reserves no space for a hidden indicator', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const DiscoveryRailViewport(
          showIndicator: false,
          child: SizedBox(width: 148, height: 240),
        ),
      ),
    );
    expect(tester.getSize(find.byType(DiscoveryRailViewport)).height, 240);
    expect(find.byType(FractionallySizedBox), findsNothing);
  });

  for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
    testWidgets('rail settles on a card edge in $direction', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          Directionality(
            textDirection: direction,
            child: SizedBox(
              width: 320,
              height: 200,
              child: ListView.builder(
                controller: controller,
                scrollDirection: Axis.horizontal,
                physics: const DiscoverySnapPhysics(
                  itemExtent: 157,
                  parent: BouncingScrollPhysics(),
                ),
                itemExtent: 157,
                itemCount: 12,
                itemBuilder: (_, index) => Text('$index'),
              ),
            ),
          ),
        ),
      );
      await tester.drag(
        find.byType(ListView),
        Offset(direction == TextDirection.ltr ? -195 : 195, 0),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));
      expect(controller.offset % 157, closeTo(0, 0.01));
      controller.jumpTo(controller.position.maxScrollExtent - 20);
      await tester.fling(
        find.byType(ListView),
        Offset(direction == TextDirection.ltr ? -160 : 160, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(
        controller.offset,
        closeTo(controller.position.maxScrollExtent, 0.01),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final reduced in [false, true]) {
    testWidgets(
      'section reveal respects reduced motion $reduced and keeps child stable',
      (tester) async {
        var builds = 0;
        await tester.pumpWidget(
          _host(
            DiscoverySectionReveal(
              child: Builder(
                builder: (_) {
                  builds++;
                  return const SizedBox(width: 100, height: 100);
                },
              ),
            ),
            reduced: reduced,
          ),
        );
        final opacity = find.descendant(
          of: find.byType(DiscoverySectionReveal),
          matching: find.byType(Opacity),
        );
        expect(tester.widget<Opacity>(opacity).opacity, reduced ? 1 : 0);
        await tester.pump(const Duration(milliseconds: 60));
        if (!reduced) {
          expect(
            tester.widget<Opacity>(opacity).opacity,
            inExclusiveRange(0, 1),
          );
        }
        await tester.pumpAndSettle();
        expect(tester.widget<Opacity>(opacity).opacity, 1);
        expect(builds, 1);
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );
  }

  testWidgets(
    'rail indicator tracks horizontal position without rebuilding content',
    (tester) async {
      var builds = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            child: DiscoveryRailViewport(
              child: SizedBox(
                height: 200,
                child: Builder(
                  builder: (_) {
                    builds++;
                    return ListView(
                      scrollDirection: Axis.horizontal,
                      children: List.generate(
                        6,
                        (index) => SizedBox(width: 160, child: Text('$index')),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final indicator = find.descendant(
        of: find.byType(DiscoveryRailViewport),
        matching: find.byType(FractionallySizedBox),
      );
      expect(
        tester.widget<FractionallySizedBox>(indicator).widthFactor,
        lessThan(1),
      );
      final align = find
          .ancestor(of: indicator, matching: find.byType(Align))
          .first;
      final before = tester.widget<Align>(align).alignment;
      await tester.drag(find.byType(ListView), const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(tester.widget<Align>(align).alignment, isNot(before));
      expect(builds, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _host(Widget child, {bool reduced = true, double scale = 1}) =>
    MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            disableAnimations: reduced,
            textScaler: TextScaler.linear(scale),
          ),
          child: Center(child: child),
        ),
      ),
    );
