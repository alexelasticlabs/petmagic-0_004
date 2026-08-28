import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_state.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_flow_sheets.dart';

void main() {
  testWidgets(
    'generation confirmation is full screen and stays overflow-free on compact displays',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await tester.pumpWidget(const _ConfirmSheetHost());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.byType(BottomSheet).last).dy, 0);
      expect(find.text('Ready to create'), findsOneWidget);
      expect(find.text('Usually takes 10–60 seconds'), findsOneWidget);
      expect(find.text('Create magic'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('generation confirmation returns false when changing photo', (
    tester,
  ) async {
    await tester.pumpWidget(const _ConfirmSheetHost());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Change photo'));
    await tester.pumpAndSettle();

    expect(find.text('result:false'), findsOneWidget);
  });
}

class _ConfirmSheetHost extends StatefulWidget {
  const _ConfirmSheetHost();

  @override
  State<_ConfirmSheetHost> createState() => _ConfirmSheetHostState();
}

class _ConfirmSheetHostState extends State<_ConfirmSheetHost> {
  bool? _result;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
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
                    final result = await showTemplateGenerationConfirmSheet(
                      context: context,
                      template: _template,
                      photo: XFile('assets/auth/petmagic-auth-hero.png'),
                      gate: _allowedGate,
                    );
                    if (!mounted) {
                      return;
                    }
                    setState(() => _result = result);
                  },
                  child: const Text('Open'),
                ),
                const SizedBox(height: 12),
                Text('result:${_result ?? 'none'}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _allowedGate = TemplateGenerationGate(
  kind: TemplateGenerationGateKind.allowed,
  balance: 20,
  isPremium: false,
);

const _template = TemplateItem(
  templateId: 'big-boss',
  templateType: TemplateType.image,
  title: 'Big Boss',
  shortDescription:
      'Your pet is now the CEO. And the quarterly report does not look good.',
  petPhotoRequirements: ['Clear photo'],
  category: 'Funny',
  tags: ['boss'],
  isPremium: false,
  tokenCost: 3,
);
