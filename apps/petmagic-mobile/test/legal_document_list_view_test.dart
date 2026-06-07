import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/legal_document_list_view.dart';

void main() {
  testWidgets('LegalDocumentListView lazily builds long documents', (
    tester,
  ) async {
    final paragraphs = List.generate(200, (index) => 'Paragraph $index');
    final document = MobileLegalDocument(
      kind: 'terms-of-use',
      title: 'Terms',
      version: '2026-06-06',
      publishedAtUtc: null,
      summary: 'Summary',
      sections: [
        MobileLegalDocumentSection(heading: 'Section', paragraphs: paragraphs),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 220,
            child: LegalDocumentListView(documents: [document]),
          ),
        ),
      ),
    );

    expect(find.text('Paragraph 0'), findsOneWidget);
    expect(find.text('Paragraph 199'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Paragraph 199'),
      500,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Paragraph 199'), findsOneWidget);
  });
}
