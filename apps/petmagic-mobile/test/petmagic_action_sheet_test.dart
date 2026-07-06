import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_action_sheet.dart';

void main() {
  testWidgets('PetMagicActionSheet moves between steps and handles back', (
    tester,
  ) async {
    await tester.pumpWidget(const _ActionSheetHost());

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Add a photo or video'), findsOneWidget);
    expect(find.text('Use a pet from your profile'), findsOneWidget);

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    expect(find.text('Content source'), findsOneWidget);
    expect(
      find.text('Choose a photo or video from your gallery'),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Content source'), findsNothing);
    expect(find.text('Use a pet from your profile'), findsOneWidget);
    expect(find.text('result:none'), findsOneWidget);
  });

  testWidgets('PetMagicActionSheet returns selected result', (tester) async {
    await tester.pumpWidget(const _ActionSheetHost());

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();

    expect(find.text('result:gallery'), findsOneWidget);
  });

  testWidgets(
    'PetMagicActionSheet surface follows light and dark theme tokens',
    (tester) async {
      for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
        await tester.pumpWidget(_ActionSheetHost(themeMode: themeMode));

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final sheetContext = tester.element(find.text('Add a photo or video'));
        final colors = sheetContext.petMagicColors;
        final gradient =
            (_sheetSurfaceDecoration(tester).gradient! as LinearGradient);

        expect(gradient.colors, [colors.surfaceGlass, colors.surface]);

        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}

class _ActionSheetHost extends StatefulWidget {
  const _ActionSheetHost({this.themeMode = ThemeMode.light});

  final ThemeMode themeMode;

  @override
  State<_ActionSheetHost> createState() => _ActionSheetHostState();
}

class _ActionSheetHostState extends State<_ActionSheetHost> {
  PetMagicActionSheetResult? _result;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: widget.themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final result = await showPetMagicActionSheet(context);
                    if (!mounted) {
                      return;
                    }

                    setState(() {
                      _result = result;
                    });
                  },
                  child: const Text('Open'),
                ),
                const SizedBox(height: 12),
                Text(
                  _result == null ? 'result:none' : 'result:${_result!.name}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _sheetSurfaceDecoration(WidgetTester tester) {
  final decoratedBox = tester.widget<DecoratedBox>(
    find.byWidgetPredicate((widget) {
      if (widget is! DecoratedBox) {
        return false;
      }

      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.borderRadius == BorderRadius.circular(32) &&
          decoration.gradient is LinearGradient;
    }),
  );

  return decoratedBox.decoration as BoxDecoration;
}
