import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/app.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('shows onboarding for first-time guest', (tester) async {
    await _pumpApp(tester);

    expect(find.text('Create magic moments with your pet'), findsOneWidget);
    expect(find.text('Continue as guest'), findsOneWidget);
  });

  testWidgets('shows short welcome for returning guest', (tester) async {
    await _pumpApp(
      tester,
      sharedPrefs: const {_onboardingSeenKey: true},
    );

    expect(find.text('Welcome back to PetMagic'), findsOneWidget);
    expect(find.text('Continue as guest'), findsOneWidget);
  });

  testWidgets('opens templates directly for authenticated user', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      sharedPrefs: {
        _onboardingSeenKey: true,
        _sessionKey: _buildSessionJson(),
      },
      repository: _FakeTemplatesRepository(items: const [_sampleTemplate]),
    );

    expect(find.text('Create Magic'), findsOneWidget);
    expect(find.text('Templates'), findsOneWidget);
    expect(find.text('Magic Studio'), findsOneWidget);
  });

  testWidgets('guest template action opens auth sheet', (tester) async {
    await _pumpApp(
      tester,
      sharedPrefs: const {_onboardingSeenKey: true},
      repository: _FakeTemplatesRepository(items: const [_sampleTemplate]),
    );

    await tester.tap(find.text('Continue as guest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Magic Studio'), findsOneWidget);

    await tester.ensureVisible(find.text('Try template'));
    await tester.tap(find.text('Try template'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Sign in to unlock this action'), findsOneWidget);
    expect(
      find.text(
        'Guests can explore the app, but template actions, rewards and token features require a PetMagic account.',
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  Map<String, Object> sharedPrefs = const {},
  TemplatesRepository? repository,
}) async {
  SharedPreferences.setMockInitialValues(sharedPrefs);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        templatesRepositoryProvider.overrideWith(
          (ref) => repository ?? _FakeTemplatesRepository(),
        ),
      ],
      child: const PetMagicApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));

  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

String _buildSessionJson() {
  return jsonEncode(
    AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAtUtc: DateTime.utc(2030, 1, 1),
      user: const MobileUserProfile(
        userId: 'user-1',
        email: 'pet@example.com',
        displayName: 'Pet Parent',
        isPremium: false,
        emailConfirmed: true,
        roles: ['user'],
        avatar: null,
      ),
    ).toJson(),
  );
}

const _sessionKey = 'petmagic_mobile_auth_session';
const _onboardingSeenKey = 'petmagic_mobile_guest_onboarding_seen';

const _sampleTemplate = TemplateItem(
  templateId: 'template-1',
  templateType: TemplateType.image,
  title: 'Magic Studio',
  shortDescription: 'Turn your pet into a star.',
  category: 'Magic',
  tags: ['funny', 'sparkle'],
  isPremium: false,
  tokenCost: 12,
);

class _FakeTemplatesRepository implements TemplatesRepository {
  const _FakeTemplatesRepository({this.items = const []});

  final List<TemplateItem> items;

  @override
  Future<List<String>> fetchCategories() async => const ['Magic'];

  @override
  Future<TemplatesFeedPage?> readCachedFirstPage(TemplatesQuery query) async =>
      null;

  @override
  Future<TemplatesFeedPage> fetchFeed(TemplatesQuery query) async =>
      TemplatesFeedPage(items: items, nextCursor: null, hasMore: false);
}
