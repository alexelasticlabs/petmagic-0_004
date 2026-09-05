import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/discovery_atmosphere.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'collection atmosphere is finite and keeps content stable: $reduced',
      (tester) async {
        final index = ValueNotifier(0);
        addTearDown(index.dispose);
        var builds = 0;
        await tester.pumpWidget(
          _host(
            DiscoveryAtmosphere(
              collectionIndex: index,
              child: Builder(
                builder: (_) {
                  builds++;
                  return const Text('Media content');
                },
              ),
            ),
            reduced: reduced,
          ),
        );
        final before = tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('discovery-atmosphere-paint')),
            )
            .painter!;
        index.value = 1;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final after = tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('discovery-atmosphere-paint')),
            )
            .painter!;
        expect(after.shouldRepaint(before), isTrue);
        expect(builds, 1);
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final brightness in Brightness.values) {
    testWidgets(
      'introduction fits large text and remains interactive in ${brightness.name}',
      (tester) async {
        final index = ValueNotifier(0);
        addTearDown(index.dispose);
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.light
                ? AppTheme.light()
                : AppTheme.dark(),
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 844),
                  textScaler: TextScaler.linear(2),
                ),
                child: SizedBox(
                  width: 320,
                  child: DiscoveryAtmosphere(
                    collectionIndex: index,
                    child: Column(
                      children: [
                        const DiscoveryIntroduction(
                          title: 'Кем станет ваш питомец?',
                          subtitle: 'Найдите новый образ для вашего питомца.',
                        ),
                        TextButton(
                          onPressed: () => taps++,
                          child: const Text('Открыть'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Открыть'));
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Widget _host(Widget child, {required bool reduced}) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        disableAnimations: reduced,
      ),
      child: child,
    ),
  ),
);
