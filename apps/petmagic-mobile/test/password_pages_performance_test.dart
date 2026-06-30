import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'profile text controller screens do not mutate controllers during build',
    () {
      for (final policy in const [
        _ControllerSyncPolicy(
          path: 'lib/features/profile/presentation/auth_entry_page.dart',
          expectedSyncCall: '_syncControllers(next);',
        ),
        _ControllerSyncPolicy(
          path: 'lib/features/profile/presentation/password_reset_page.dart',
          expectedSyncCall: '_syncControllers(next);',
        ),
        _ControllerSyncPolicy(
          path: 'lib/features/profile/presentation/password_change_page.dart',
          expectedSyncCall: '_syncControllers(next);',
        ),
        _ControllerSyncPolicy(
          path:
              'lib/features/profile/presentation/profile_settings_detail_page.dart',
          expectedSyncCall: '_syncDisplayNameController(next);',
        ),
      ]) {
        final path = policy.path;
        final source = File(path).readAsStringSync();
        final buildBodies = _methodBodies(source, 'build').toList();

        expect(
          buildBodies,
          isNotEmpty,
          reason: '$path must have build methods.',
        );

        for (final buildBody in buildBodies) {
          expect(
            buildBody,
            isNot(contains('_syncController(')),
            reason: '$path must keep TextEditingController sync outside build.',
          );
          expect(
            RegExp(r'_\w+Controller\.value\s=').hasMatch(buildBody),
            isFalse,
            reason: '$path must not mutate controller values during rebuilds.',
          );
          expect(
            RegExp(r'_\w+Controller\.text\s=').hasMatch(buildBody),
            isFalse,
            reason: '$path must not assign controller text during rebuilds.',
          );
        }
        expect(
          source,
          contains(policy.expectedSyncCall),
          reason: '$path must sync fields from provider state changes instead.',
        );
      }
    },
  );

  test('password reset form uses a lazy scroll surface', () {
    final source = File(
      'lib/features/profile/presentation/password_reset_page.dart',
    ).readAsStringSync();
    final buildBody = _methodBodies(source, 'build').single;

    expect(buildBody, contains('child: ListView('));
    expect(buildBody, isNot(contains('SingleChildScrollView(')));
  });

  test('password change form uses a lazy scroll surface', () {
    final source = File(
      'lib/features/profile/presentation/password_change_page.dart',
    ).readAsStringSync();
    final buildBody = _methodBodies(
      source,
      'build',
    ).singleWhere((body) => body.contains('ProfileScreenBackground'));

    expect(buildBody, contains('child: ListView('));
    expect(buildBody, isNot(contains('SingleChildScrollView(')));
  });

  test('password change step labels use localizations', () {
    final source = File(
      'lib/features/profile/presentation/password_change_page.dart',
    ).readAsStringSync();

    expect(source, contains('passwordChangeStepRequestCode'));
    expect(source, contains('passwordChangeStepNewPassword'));
    expect(source, isNot(contains('Запрос кода')));
    expect(source, isNot(contains('Новый пароль')));
    expect(source, isNot(contains('Индикатор шагов')));
    expect(source, isNot(contains('Email карточка')));
  });

  test('auth entry form uses a lazy scroll surface', () {
    final source = File(
      'lib/features/profile/presentation/auth_entry_page.dart',
    ).readAsStringSync();
    final buildBody = _methodBodies(
      source,
      'build',
    ).singleWhere((body) => body.contains('AuthBackdrop'));

    expect(buildBody, contains('child: ListView('));
    expect(buildBody, isNot(contains('SingleChildScrollView(')));
    expect(buildBody, isNot(contains('child: LayoutBuilder(')));
  });

  test('auth entry legal consent link labels use localizations', () {
    final pageSource = File(
      'lib/features/profile/presentation/auth_entry_page.dart',
    ).readAsStringSync();
    final contentSource = File(
      'lib/features/profile/presentation/auth_entry_content.part.dart',
    ).readAsStringSync();
    final consentSource = File(
      'lib/features/profile/presentation/auth_entry_consent.part.dart',
    ).readAsStringSync();
    final source = '$pageSource\n$contentSource\n$consentSource';

    expect(pageSource, contains("part 'auth_entry_consent.part.dart';"));
    expect(pageSource, contains("part 'auth_entry_content.part.dart';"));
    expect(pageSource, isNot(contains('class _SocialProviderButton')));
    expect(pageSource, isNot(contains('class _TermsConsentOption')));
    expect(contentSource, contains('class _SocialProviderButton'));
    expect(contentSource, isNot(contains('class _TermsConsentOption')));
    expect(consentSource, contains("part of 'auth_entry_page.dart';"));
    expect(consentSource, contains('class _TermsConsentOption'));
    expect(consentSource, contains('class _ConsentLabelSplit'));
    expect(source, contains('authTermsLinkText'));
    expect(source, contains('authPrivacyLinkText'));
    expect(source, isNot(contains('class _LegalConsentPhrases')));
    expect(source, isNot(contains('Условия использования')));
    expect(source, isNot(contains('Политику конфиденциальности')));
  });

  test(
    'profile account info page keeps account cards split from orchestration',
    () {
      final pageSource = File(
        'lib/features/profile/presentation/profile_settings_detail_page.dart',
      ).readAsStringSync();
      final accountContentSource = File(
        'lib/features/profile/presentation/profile_account_info_content.part.dart',
      ).readAsStringSync();

      expect(
        pageSource,
        contains("part 'profile_account_info_content.part.dart';"),
      );
      expect(pageSource, isNot(contains('class _AccountProfileHeroCard')));
      expect(accountContentSource, contains('class _AccountProfileHeroCard'));
      expect(accountContentSource, contains('class _ProfileEditableNameCard'));
    },
  );
}

class _ControllerSyncPolicy {
  const _ControllerSyncPolicy({
    required this.path,
    required this.expectedSyncCall,
  });

  final String path;
  final String expectedSyncCall;
}

Iterable<String> _methodBodies(String source, String methodName) sync* {
  final methodPattern = RegExp(
    r'(?:Widget|void|Future<[^>]+>)\s+' + methodName + r'\s*\(',
  );

  for (final methodMatch in methodPattern.allMatches(source)) {
    final openBraceIndex = _methodOpenBraceIndex(source, methodMatch);
    if (openBraceIndex < 0) {
      fail('Method $methodName has no body.');
    }

    yield _bodyFromOpenBrace(source, openBraceIndex, methodName);
  }
}

String _bodyFromOpenBrace(String source, int openBraceIndex, String label) {
  var depth = 0;
  for (var index = openBraceIndex; index < source.length; index++) {
    final char = source[index];
    if (char == '{') {
      depth++;
      continue;
    }
    if (char != '}') {
      continue;
    }

    depth--;
    if (depth == 0) {
      return source.substring(openBraceIndex, index + 1);
    }
  }
  fail('Method $label body did not close.');
}

int _methodOpenBraceIndex(String source, RegExpMatch methodMatch) {
  var parenDepth = 0;
  for (var index = methodMatch.end - 1; index < source.length; index++) {
    final char = source[index];
    if (char == '(') {
      parenDepth++;
      continue;
    }
    if (char == ')') {
      parenDepth--;
      continue;
    }
    if (char == '{' && parenDepth == 0) {
      return index;
    }
  }

  return -1;
}
