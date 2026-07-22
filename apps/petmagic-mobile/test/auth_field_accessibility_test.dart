import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_flow_widgets.dart';

void main() {
  testWidgets('AuthField exposes its visible label to accessibility services', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthField(
            controller: controller,
            hintText: 'Email address',
            prefixIcon: Icons.mail_outline,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final semanticsNode = tester.getSemantics(find.byType(TextField));
    expect(semanticsNode.label, 'Email address');
    expect(semanticsNode.flagsCollection.isTextField, isTrue);
    semantics.dispose();
  });
}
