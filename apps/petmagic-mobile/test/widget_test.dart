import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/app.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

void main() {
  testWidgets('renders templates tab shell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templatesRepositoryProvider.overrideWith(
            (ref) => _FakeTemplatesRepository(),
          ),
        ],
        child: const PetMagicApp(),
      ),
    );
    await tester.pump();

    expect(find.text('PetMagic'), findsOneWidget);
    expect(find.text('Create Magic'), findsOneWidget);
    expect(find.text('Templates'), findsOneWidget);
  });
}

class _FakeTemplatesRepository implements TemplatesRepository {
  @override
  Future<List<String>> fetchCategories() async => const ['Magic'];

  @override
  Future<TemplatesFeedPage?> readCachedFirstPage(TemplatesQuery query) async =>
      null;

  @override
  Future<TemplatesFeedPage> fetchFeed(TemplatesQuery query) async =>
      const TemplatesFeedPage(items: [], nextCursor: null, hasMore: false);
}
