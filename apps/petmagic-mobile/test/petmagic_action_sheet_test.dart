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
}

class _ActionSheetHost extends StatefulWidget {
  const _ActionSheetHost();

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
