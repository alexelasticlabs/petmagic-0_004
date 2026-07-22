import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('non-idempotent API flows disable transient retry', () {
    final expectations = <String, List<String>>{
      'lib/features/templates/data/template_generation_repository.dart': [
        'startGeneration',
        'deleteGeneration',
      ],
      'lib/features/templates/data/generation_engagement_repository_delegate.dart':
          [
            'submitGenerationFeedback',
            'registerPushToken',
            'unregisterPushToken',
          ],
      'lib/features/support/data/support_chat_repository.dart': [
        'openConversation',
        'sendMessage',
        'sendAttachment',
        'sendAttachments',
        'retryAttachment',
        'markConversationRead',
        'resolveConversation',
        'reopenConversation',
        'closeConversation',
        'submitFeedback',
        'registerPushToken',
        'unregisterPushToken',
      ],
      'lib/features/profile/data/profile_repository.dart': [
        'requestCurrentPasswordChangeCode',
        'confirmCurrentPasswordChange',
        'deleteCurrentAccount',
        'updateProfile',
        'acceptCurrentLegalDocuments',
        'uploadAvatar',
        'removeAvatar',
        'unlinkLinkedAccount',
      ],
      'lib/features/premium/data/premium_repository.dart': [
        'createStripeCheckout',
        'createBillingPortal',
        'cancelSubscription',
        'verifyStorePurchase',
        'verifyStripeSubscriptionCheckout',
      ],
      'lib/features/wallet/data/wallet_repository.dart': [
        'createPurchase',
        'verifyStorePurchase',
        'claimAdReward',
        'applyRedeemCode',
        'applyReferralCode',
        'verifyStripeCheckoutSession',
        'registerPushToken',
        'unregisterPushToken',
      ],
    };

    for (final entry in expectations.entries) {
      final source = _readRepositorySource(entry.key);
      for (final methodName in entry.value) {
        final body = _methodBody(source, methodName);
        expect(
          body,
          contains('retryTransientFailures: false'),
          reason:
              '$methodName in ${entry.key} must not retry transient failures automatically.',
        );
      }
    }
  });
}

String _readRepositorySource(String path) {
  final paths = switch (path) {
    'lib/features/profile/data/profile_repository.dart' => [
      path,
      'lib/features/profile/data/profile_auth_repository_mixin.part.dart',
    ],
    'lib/features/support/data/support_chat_repository.dart' => [
      path,
      'lib/features/support/data/support_attachment_repository_mixin.part.dart',
    ],
    'lib/features/wallet/data/wallet_repository.dart' => [
      path,
      'lib/features/wallet/data/wallet_store_repository_mixin.part.dart',
      'lib/features/wallet/data/wallet_actions_repository_mixin.part.dart',
    ],
    _ => [path],
  };
  return paths.map((item) => File(item).readAsStringSync()).join('\n');
}

String _methodBody(String source, String methodName) {
  final methodIndex = source.indexOf(RegExp('\\b$methodName\\b'));
  if (methodIndex < 0) {
    fail('Method $methodName was not found.');
  }

  final asyncBodyIndex = source.indexOf('async {', methodIndex);
  final openBraceIndex = asyncBodyIndex < 0
      ? source.indexOf('{', methodIndex)
      : source.indexOf('{', asyncBodyIndex);
  if (openBraceIndex < 0) {
    fail('Method $methodName has no body.');
  }

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

  fail('Method $methodName body did not close.');
}
