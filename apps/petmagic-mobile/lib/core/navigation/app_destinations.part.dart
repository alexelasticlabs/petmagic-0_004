part of 'app_navigator.dart';

final class CreateDestination extends AppDestination {
  const CreateDestination({this.source});

  final String? source;

  @override
  String get location {
    final normalized = _normalizeQueryValue(source, maxLength: 32);
    return Uri(
      path: '/create',
      queryParameters: normalized == null ? null : {'source': normalized},
    ).toString();
  }
}

final class CreationsDestination extends AppDestination {
  const CreationsDestination();

  @override
  String get location => '/creations';
}

final class RewardsDestination extends AppDestination {
  const RewardsDestination();

  @override
  String get location => '/rewards';
}

final class ProfileDestination extends AppDestination {
  const ProfileDestination();

  @override
  String get location => '/profile';
}

final class WelcomeDestination extends AppDestination {
  const WelcomeDestination();

  @override
  String get location => '/welcome';
}

final class LegalAcceptanceDestination extends AppDestination {
  const LegalAcceptanceDestination();

  @override
  String get location => '/legal-gate';
}

final class PetsDestination extends AppDestination {
  const PetsDestination();

  @override
  String get location => '/profile/pets';
}

final class PetDetailsDestination extends AppDestination {
  const PetDetailsDestination(this.petId);

  final String petId;

  @override
  String get location => '/profile/pets/${Uri.encodeComponent(petId)}';
}

final class AchievementsDestination extends AppDestination {
  const AchievementsDestination();

  @override
  String get location => '/profile/achievements';
}

final class SupportDestination extends AppDestination {
  const SupportDestination();

  @override
  String get location => '/profile/support';
}

final class SupportChatDestination extends AppDestination {
  const SupportChatDestination({this.initialMessage, this.relatedGenerationId});

  final String? initialMessage;
  final String? relatedGenerationId;

  @override
  String get location {
    final message = _normalizeQueryValue(initialMessage, maxLength: 500);
    final generationId = _normalizeQueryValue(
      relatedGenerationId,
      maxLength: 128,
    );
    final queryParameters = <String, String>{
      'initialMessage': ?message,
      'relatedGenerationId': ?generationId,
    };
    return Uri(
      path: '/profile/support/chat',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    ).toString();
  }
}

final class WalletDestination extends AppDestination {
  const WalletDestination();

  @override
  String get location => '/profile/wallet';
}

final class PremiumDestination extends AppDestination {
  const PremiumDestination();

  @override
  String get location => '/profile/premium';
}

final class SubscriptionManagementDestination extends AppDestination {
  const SubscriptionManagementDestination();

  @override
  String get location => '/profile/subscription/manage';
}

final class ProfileSettingsDestination extends AppDestination {
  const ProfileSettingsDestination();

  @override
  String get location => '/profile/settings';
}

final class StorageManagementDestination extends AppDestination {
  const StorageManagementDestination();

  @override
  String get location => '/profile/settings/storage';
}

final class ProfileAccountDestination extends AppDestination {
  const ProfileAccountDestination();

  @override
  String get location => '/profile/settings/account';
}

final class ProfileSettingsDetailDestination extends AppDestination {
  const ProfileSettingsDetailDestination(this.kind);

  final String kind;

  @override
  String get location =>
      '/profile/settings/detail/${Uri.encodeComponent(kind)}';
}

final class PasswordChangeDestination extends AppDestination {
  const PasswordChangeDestination({this.payload});

  final Object? payload;

  @override
  String get location => '/profile/settings/password-change';

  @override
  Object? get extra => payload;
}

final class AllTransactionsDestination extends AppDestination {
  const AllTransactionsDestination();

  @override
  String get location => '/profile/wallet/transactions';
}

final class GenerationDestination extends AppDestination {
  const GenerationDestination(this.generationId, {this.payload});

  final String generationId;
  final Object? payload;

  @override
  String get location => '/generations/$generationId';

  @override
  Object? get extra => payload;
}

final class GenerationResultInputDestination extends AppDestination {
  const GenerationResultInputDestination(
    this.generationId, {
    this.selectedTemplateId,
  });

  final String generationId;
  final String? selectedTemplateId;

  @override
  String get location {
    final path =
        '/generation-results/${Uri.encodeComponent(generationId)}/use-input';
    final templateId = selectedTemplateId?.trim();
    return templateId == null || templateId.isEmpty
        ? path
        : '$path?template=${Uri.encodeQueryComponent(templateId)}';
  }
}

final class TemplatePreviewDestination extends AppDestination {
  const TemplatePreviewDestination({this.templateId, this.payload});

  final String? templateId;
  final Object? payload;

  @override
  String get location {
    final id = templateId?.trim();
    return id == null || id.isEmpty
        ? '/templates/preview'
        : '/templates/preview/${Uri.encodeComponent(id)}';
  }

  @override
  Object? get extra => payload;
}

final class SupportAssistantDestination extends AppDestination {
  const SupportAssistantDestination({this.scenario});

  final String? scenario;

  @override
  String get location =>
      _locationWithOptionalScenario('/profile/support/assistant', scenario);
}

final class SupportTicketDestination extends AppDestination {
  const SupportTicketDestination({this.scenario});

  final String? scenario;

  @override
  String get location =>
      _locationWithOptionalScenario('/profile/support/ticket', scenario);
}

final class AuthDestination extends AppDestination {
  const AuthDestination({this.redirectPath, this.payload});

  final String? redirectPath;
  final Object? payload;

  @override
  String get location {
    final redirect = redirectPath;
    if (redirect == null || redirect.isEmpty) return '/auth';
    return '/auth?redirect=${Uri.encodeQueryComponent(redirect)}';
  }

  @override
  Object? get extra => payload;
}

final class RegisterDestination extends AppDestination {
  const RegisterDestination({this.redirectPath});

  final String? redirectPath;

  @override
  String get location {
    final redirect = redirectPath;
    if (redirect == null || redirect.isEmpty) return '/register';
    return '/register?redirect=${Uri.encodeQueryComponent(redirect)}';
  }
}

final class PasswordResetDestination extends AppDestination {
  const PasswordResetDestination({this.email, this.redirectPath, this.payload});

  final String? email;
  final String? redirectPath;
  final Object? payload;

  @override
  String get location => _authLocation(
    '/password-reset',
    email: email,
    redirectPath: redirectPath,
  );

  @override
  Object? get extra => payload;
}

final class EmailVerificationDestination extends AppDestination {
  const EmailVerificationDestination({
    this.email,
    this.redirectPath,
    this.payload,
  });

  final String? email;
  final String? redirectPath;
  final Object? payload;

  @override
  String get location =>
      _authLocation('/verify-email', email: email, redirectPath: redirectPath);

  @override
  Object? get extra => payload;
}

final class SafeRedirectDestination extends AppDestination {
  SafeRedirectDestination(String? location)
    : _location = normalizeAuthRedirectPath(location) ?? '/discover';

  final String _location;

  @override
  String get location => _location;
}

const int maxAuthRedirectPathLength = 1024;
final RegExp _authRedirectControlPattern = RegExp(r'[\x00-\x1F\x7F]');

String? _normalizeQueryValue(String? value, {required int maxLength}) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  return normalized.length <= maxLength
      ? normalized
      : normalized.substring(0, maxLength);
}

String _locationWithOptionalScenario(String path, String? scenario) {
  final normalized = _normalizeQueryValue(scenario, maxLength: 128);
  return Uri(
    path: path,
    queryParameters: normalized == null ? null : {'scenario': normalized},
  ).toString();
}

String _authLocation(String path, {String? email, String? redirectPath}) {
  final normalizedEmail = _normalizeQueryValue(email, maxLength: 320);
  final normalizedRedirect = normalizeAuthRedirectPath(redirectPath);
  return Uri(
    path: path,
    queryParameters:
        {'email': ?normalizedEmail, 'redirect': ?normalizedRedirect}.isEmpty
        ? null
        : {'email': ?normalizedEmail, 'redirect': ?normalizedRedirect},
  ).toString();
}

String? normalizeAuthRedirectPath(String? redirectPath) {
  final normalized = redirectPath?.trim();
  if (normalized == null ||
      normalized.isEmpty ||
      normalized.length > maxAuthRedirectPathLength ||
      !normalized.startsWith('/') ||
      normalized.startsWith('//') ||
      normalized.contains(r'\') ||
      _authRedirectControlPattern.hasMatch(normalized)) {
    return null;
  }

  final uri = Uri.tryParse(normalized);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  return normalized;
}
