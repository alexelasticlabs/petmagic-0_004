import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';

void main() {
  test('typed destinations preserve production route contracts', () {
    expect(const TemplatesDestination().location, '/templates');
    expect(
      const TemplatesDestination(
        petId: 'pet 1',
        petPhotoId: 'photo/2',
      ).location,
      '/templates?petId=pet+1&petPhotoId=photo%2F2',
    );
    expect(
      const TemplatesDestination(petPhotoId: 'orphan-photo').location,
      '/templates',
    );
    expect(const LegalAcceptanceDestination().location, '/legal-gate');
    expect(const PetsDestination().location, '/profile/pets');
    expect(
      const GenerationResultInputDestination('generation/1').location,
      '/generation-results/generation%2F1/use-input',
    );
    expect(
      const TemplatePreviewDestination(templateId: 'template/1').location,
      '/templates/preview/template%2F1',
    );
    expect(
      const ProfileSettingsDetailDestination('linked-accounts').location,
      '/profile/settings/detail/linked-accounts',
    );
  });

  test('support destination bounds untrusted query values', () {
    final destination = SupportChatDestination(
      initialMessage: List.filled(300, ' x ').join(),
      relatedGenerationId: ' generation-1 ',
    );
    final uri = Uri.parse(destination.location);

    expect(uri.path, '/profile/support/chat');
    expect(uri.queryParameters['initialMessage']!.length, 500);
    expect(uri.queryParameters['relatedGenerationId'], 'generation-1');
  });

  test('auth destinations encode internal redirects', () {
    expect(
      const AuthDestination(redirectPath: '/templates?petId=pet 1').location,
      '/auth?redirect=%2Ftemplates%3FpetId%3Dpet+1',
    );
    expect(normalizeAuthRedirectPath('https://example.test'), isNull);
    expect(normalizeAuthRedirectPath('//example.test/path'), isNull);
    expect(normalizeAuthRedirectPath('/profile/wallet'), '/profile/wallet');
    expect(
      EmailVerificationDestination(
        email: 'owner+pet@example.test',
        redirectPath: '/profile',
      ).location,
      '/verify-email?email=owner%2Bpet%40example.test&redirect=%2Fprofile',
    );
    expect(
      SafeRedirectDestination('https://example.test').location,
      '/templates',
    );
  });

  test('scenario destinations normalize their query contract', () {
    expect(
      const SupportAssistantDestination(
        scenario: ' Billing & Premium ',
      ).location,
      '/profile/support/assistant?scenario=Billing+%26+Premium',
    );
    expect(
      const SupportTicketDestination(scenario: ' Generation issue ').location,
      '/profile/support/ticket?scenario=Generation+issue',
    );
  });
}
