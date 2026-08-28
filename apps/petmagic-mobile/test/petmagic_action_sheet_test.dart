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

    expect(find.text('Add a photo'), findsOneWidget);
    expect(find.text('Upload from device'), findsOneWidget);
    expect(find.text('Use a pet from your profile'), findsOneWidget);

    expect(tester.getTopLeft(find.byType(BottomSheet).last).dy, 0);

    await tester.tap(find.text('Upload from device'));
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
    await tester.tap(find.text('Upload from device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();

    expect(find.text('result:gallery'), findsOneWidget);
  });

  testWidgets(
    'PetMagicActionSheet uses a plain themed surface without backdrop blur',
    (tester) async {
      for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
        await tester.pumpWidget(_ActionSheetHost(themeMode: themeMode));

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final sheetContext = tester.element(find.text('Add a photo'));
        final colors = sheetContext.petMagicColors;
        final decoration = _sheetSurfaceDecoration(tester, colors);

        expect(decoration.color, colors.surface);
        expect(decoration.gradient, isNull);
        expect(find.byType(BackdropFilter), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets('PetMagicActionSheet closes from its header action', (
    tester,
  ) async {
    await tester.pumpWidget(const _ActionSheetHost());

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Add a photo'), findsNothing);
    expect(find.text('result:none'), findsOneWidget);
  });

  testWidgets('PetMagicActionSheet stays overflow-free on a compact screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(const _ActionSheetHost());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byType(BottomSheet).last).dy, 0);
    expect(tester.takeException(), isNull);
  });
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

BoxDecoration _sheetSurfaceDecoration(
  WidgetTester tester,
  PetMagicColors colors,
) {
  final decoratedBox = tester.widget<DecoratedBox>(
    find.byWidgetPredicate((widget) {
      if (widget is! DecoratedBox) {
        return false;
      }

      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.color == colors.surface &&
          decoration.gradient == null;
    }),
  );

  return decoratedBox.decoration as BoxDecoration;
}
