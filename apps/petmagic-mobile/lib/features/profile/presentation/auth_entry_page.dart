import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/data/external_auth_repository.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/email_verification_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_reset_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_flow_widgets.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/legal_document_list_view.dart';
import 'package:petmagic_mobile/features/startup/presentation/guest_welcome_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';

class AuthEntryPage extends StatelessWidget {
  const AuthEntryPage({super.key, this.initialEmail, this.redirectPath});

  static const routePath = '/auth';

  final String? initialEmail;
  final String? redirectPath;

  @override
  Widget build(BuildContext context) {
    return _AuthFlowPage(
      mode: _AuthMode.signIn,
      initialEmail: initialEmail,
      redirectPath: redirectPath,
    );
  }
}

class RegisterEntryPage extends StatelessWidget {
  const RegisterEntryPage({super.key});

  static const routePath = '/register';

  @override
  Widget build(BuildContext context) {
    return const _AuthFlowPage(mode: _AuthMode.signUp);
  }
}

enum _AuthMode { signIn, signUp }

class _AuthFlowPage extends ConsumerStatefulWidget {
  const _AuthFlowPage({
    required this.mode,
    this.initialEmail,
    this.redirectPath,
  });

  final _AuthMode mode;
  final String? initialEmail;
  final String? redirectPath;

  @override
  ConsumerState<_AuthFlowPage> createState() => _AuthFlowPageState();
}

class _AuthFlowPageState extends ConsumerState<_AuthFlowPage> {
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  bool _receiveUpdates = false;
  String? _consentErrorMessage;

  bool get _isSignUp => widget.mode == _AuthMode.signUp;

  @override
  void initState() {
    super.initState();
    AppLogger.info(
      feature: 'Profile.Auth',
      operation: 'login_screen_opened',
      message: 'login_screen_opened',
      context: {'event': 'login_screen_opened'},
    );
    Future.microtask(() {
      if (!mounted) {
        return;
      }

      ref
          .read(profileControllerProvider.notifier)
          .initialize(initialEmail: widget.initialEmail?.trim() ?? '');
      _syncControllers(ref.read(profileControllerProvider));
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final controller = ref.read(profileControllerProvider.notifier);
    final launchState = ref.watch(appLaunchControllerProvider);
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final legalDocumentsAsync = ref.watch(
      currentLegalDocumentsProvider(locale),
    );

    final title = _isSignUp ? text.authRegisterTitle : text.authEntryTitle;
    final subtitle = _isSignUp
        ? text.authRegisterSubtitle
        : text.authEntrySubtitle;
    final primaryAction = _isSignUp
        ? text.authRegisterAction
        : text.profileSignInAction;
    final switchPrompt = _isSignUp
        ? text.authHaveAccountPrompt
        : text.authNoAccountPrompt;
    final switchAction = _isSignUp
        ? text.profileSignInAction
        : text.authSignUpAction;
    final confirmPasswordMismatch =
        _isSignUp &&
        _confirmPasswordController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text != _passwordController.text;
    final submitDisabled =
        state.isSaving || (_isSignUp && confirmPasswordMismatch);
    final showAppleSignIn = !kIsWeb && Platform.isIOS;

    ref.listen(profileControllerProvider, (previous, next) {
      if (!mounted) {
        return;
      }

      _syncControllers(next);

      final previousError = previous?.errorMessage;
      if (next.errorMessage != null && next.errorMessage != previousError) {
        PetMagicToast.show(
          context,
          message: _mapErrorMessage(next.errorMessage!, text),
          tone: PetMagicToastTone.warning,
        );
      }

      final previousSuccess = previous?.successMessage;
      if (next.successMessage != null &&
          next.successMessage != previousSuccess) {
        final successMessage = _mapSuccessMessage(next.successMessage!, text);
        if (successMessage != null) {
          PetMagicToast.show(
            context,
            message: successMessage,
            tone: PetMagicToastTone.success,
          );
        }
      }
    });

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.backgroundTop, colors.backgroundBottom],
          ),
        ),
        child: Stack(
          children: [
            const AuthBackdrop(),
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                children: [
                  Row(
                    children: [
                      IconButton.outlined(
                        onPressed: () => _handleBack(launchState),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  AuthHero(title: title, subtitle: subtitle, isDark: isDark),
                  if (_isSignUp) ...[
                    const SizedBox(height: 10),
                    _SignUpHighlights(
                      secureTitle: text.authSecurePrivateTitle,
                      secureSubtitle: text.authSecurePrivateSubtitle,
                      fastTitle: text.authFastEasyTitle,
                      fastSubtitle: text.authFastEasySubtitle,
                      lovedTitle: text.authLovedByPetsTitle,
                      lovedSubtitle: text.authLovedByPetsSubtitle,
                    ),
                  ],
                  const SizedBox(height: 2),
                  if (_consentErrorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ErrorCard(
                        message: _mapErrorMessage(_consentErrorMessage!, text),
                      ),
                    ),
                  AuthFormCard(
                    isDark: isDark,
                    child: Column(
                      children: [
                        if (_isSignUp) ...[
                          AuthField(
                            controller: _displayNameController,
                            hintText: text.authDisplayNameLabel,
                            prefixIcon: Icons.badge_outlined,
                            textInputAction: TextInputAction.next,
                            onChanged: controller.updateDisplayName,
                            enabled: !state.isSaving,
                          ),
                          const SizedBox(height: 8),
                        ],
                        AuthField(
                          controller: _emailController,
                          hintText: text.profileEmailLabel,
                          prefixIcon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onChanged: controller.updateEmail,
                          enabled: !state.isSaving,
                        ),
                        const SizedBox(height: 8),
                        AuthField(
                          controller: _passwordController,
                          hintText: text.profilePasswordLabel,
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          textInputAction: _isSignUp
                              ? TextInputAction.next
                              : TextInputAction.done,
                          onChanged: controller.updatePassword,
                          enabled: !state.isSaving,
                          trailing: IconButton(
                            onPressed: state.isSaving
                                ? null
                                : () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        if (_isSignUp) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: Text(
                                text.authPasswordRulesHint,
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 10.8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          AuthField(
                            controller: _confirmPasswordController,
                            hintText: text.authConfirmPasswordLabel,
                            prefixIcon: Icons.lock_person_outlined,
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            onChanged: controller.updateConfirmPassword,
                            enabled: !state.isSaving,
                            errorText: confirmPasswordMismatch
                                ? text.authPasswordMismatch
                                : null,
                            trailing: IconButton(
                              onPressed: state.isSaving
                                  ? null
                                  : () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_isSignUp) ...[
                    const SizedBox(height: 12),
                    _TermsConsentOption(
                      value: _acceptedTerms,
                      label: text.authAcceptTermsLabel,
                      locale: Localizations.localeOf(context),
                      onOpenTerms: () => _openLegalDocument(
                        legalDocuments: legalDocumentsAsync.value,
                        documentSelector: (docs) => docs.termsOfUse,
                      ),
                      onOpenPrivacy: () => _openLegalDocument(
                        legalDocuments: legalDocumentsAsync.value,
                        documentSelector: (docs) => docs.privacyPolicy,
                      ),
                      showError:
                          _consentErrorMessage == 'auth.accept_terms_required',
                      onChanged: (value) {
                        setState(() {
                          _acceptedTerms = value ?? false;
                          _consentErrorMessage = null;
                        });
                      },
                    ),
                    if (legalDocumentsAsync.hasError) ...[
                      const SizedBox(height: 4),
                      _LegalStateLine(
                        message: text.authLegalUnavailable,
                        isError: true,
                      ),
                    ] else if (legalDocumentsAsync.isLoading) ...[
                      const SizedBox(height: 4),
                      _LegalStateLine(message: text.authLegalLoading),
                    ],
                    const SizedBox(height: 4),
                    _MarketingConsentOption(
                      value: _receiveUpdates,
                      title: text.authReceiveUpdatesLabel,
                      onChanged: (value) {
                        setState(() {
                          _receiveUpdates = value ?? false;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  _AuthInlineActions(
                    isSignUp: _isSignUp,
                    switchPrompt: switchPrompt,
                    switchAction: switchAction,
                    forgotPasswordAction: text.authForgotPasswordAction,
                    onForgotPassword: () {
                      final email = _emailController.text.trim();
                      final query = email.isEmpty
                          ? ''
                          : '?email=${Uri.encodeQueryComponent(email)}';
                      context.go('${PasswordResetPage.routePath}$query');
                    },
                    onSwitchMode: () {
                      context.go(
                        _isSignUp
                            ? AuthEntryPage.routePath
                            : RegisterEntryPage.routePath,
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: submitDisabled ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0.6,
                      ),
                      child: Text(
                        state.isSaving
                            ? text.profileLoadingAction
                            : primaryAction,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AuthDivider(label: text.authOrContinueWith),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: SocialButton(
                          icon: SocialGlyph.google(),
                          label: text.authContinueWithGoogle,
                          onPressed: state.isSaving
                              ? null
                              : () => _submitExternal(
                                  ExternalAuthProvider.google,
                                ),
                        ),
                      ),
                      if (showAppleSignIn) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: SocialButton(
                            icon: SocialGlyph.apple(),
                            label: text.authContinueWithApple,
                            onPressed: state.isSaving
                                ? null
                                : () => _submitExternal(
                                    ExternalAuthProvider.apple,
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  LightPrivacyPanel(
                    title: text.authPrivacyTitle,
                    subtitle: text.authPrivacySubtitle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final controller = ref.read(profileControllerProvider.notifier);
    final router = GoRouter.of(context);
    if (_isSignUp) {
      final locale = Localizations.localeOf(context).toLanguageTag();
      final legalDocuments = switch (ref.read(
        currentLegalDocumentsProvider(locale),
      )) {
        AsyncData(:final value) => value,
        _ => null,
      };

      if (legalDocuments == null) {
        setState(() {
          _consentErrorMessage = 'auth.legal_documents_unavailable';
        });
        return;
      }

      if (!_acceptedTerms) {
        setState(() {
          _consentErrorMessage = 'auth.accept_terms_required';
        });
        return;
      }

      await controller.register(
        termsOfUseAccepted: _acceptedTerms,
        privacyPolicyAccepted: _acceptedTerms,
        legalDocuments: legalDocuments,
        marketingEmailsEnabled: _receiveUpdates,
      );
    } else {
      await controller.login();
    }

    if (!mounted) {
      return;
    }

    final nextState = ref.read(profileControllerProvider);
    if (!nextState.isAuthenticated || !context.mounted) {
      if (_isSignUp &&
          nextState.successMessage ==
              'auth.registration_pending_verification') {
        final email = nextState.email.trim();
        router.go(
          '${EmailVerificationPage.routePath}?email=${Uri.encodeQueryComponent(email)}',
        );
      }
      return;
    }
    router.go(_resolvePostAuthRoute());
  }

  Future<void> _submitExternal(ExternalAuthProvider provider) async {
    AppLogger.info(
      feature: 'Profile.Auth',
      operation: provider == ExternalAuthProvider.apple
          ? 'apple_login_clicked'
          : 'google_login_clicked',
      message: provider == ExternalAuthProvider.apple
          ? 'apple_login_clicked'
          : 'google_login_clicked',
      context: {
        'event': provider == ExternalAuthProvider.apple
            ? 'apple_login_clicked'
            : 'google_login_clicked',
        'provider': provider.apiValue,
      },
    );
    final controller = ref.read(profileControllerProvider.notifier);
    final router = GoRouter.of(context);
    await controller.authenticateWithProvider(provider);

    if (!mounted) {
      return;
    }

    final nextState = ref.read(profileControllerProvider);
    if (!nextState.isAuthenticated || !context.mounted) {
      return;
    }

    router.go(_resolvePostAuthRoute());
  }

  void _handleBack(AppLaunchState launchState) {
    if (_isSignUp) {
      context.go(AuthEntryPage.routePath);
      return;
    }

    if (launchState.guestSessionReady) {
      context.go(TemplatesPage.routePath);
      return;
    }

    context.go(GuestWelcomePage.routePath);
  }

  void _syncControllers(ProfileState state) {
    _syncController(_displayNameController, state.displayName);
    _syncController(_emailController, state.email);
    _syncController(_passwordController, state.password);
    _syncController(_confirmPasswordController, state.confirmPassword);
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  String _resolvePostAuthRoute() {
    final redirectPath = widget.redirectPath?.trim();
    if (redirectPath == null || redirectPath.isEmpty) {
      return TemplatesPage.routePath;
    }

    if (!redirectPath.startsWith('/')) {
      return TemplatesPage.routePath;
    }

    return redirectPath;
  }

  String _mapErrorMessage(String raw, AppLocalizations text) {
    return mapProfileFeedbackMessage(raw, text);
  }

  String? _mapSuccessMessage(String raw, AppLocalizations text) {
    switch (raw) {
      case 'logout':
        return text.profileSignedOut;
      case 'auth.registration_pending_verification':
        return null;
      default:
        return null;
    }
  }

  Future<void> _openLegalDocument({
    required MobileLegalDocuments? legalDocuments,
    required MobileLegalDocument Function(MobileLegalDocuments docs)
    documentSelector,
  }) async {
    if (legalDocuments == null) {
      return;
    }

    final document = documentSelector(legalDocuments);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: false,
      builder: (context) => _LegalDocumentSheet(document: document),
    );
  }
}

class _LegalDocumentSheet extends StatelessWidget {
  const _LegalDocumentSheet({required this.document});

  final MobileLegalDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    document.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: LegalDocumentListView(
              documents: [document],
              includeDocumentTitles: false,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsConsentOption extends StatelessWidget {
  const _TermsConsentOption({
    required this.value,
    required this.label,
    required this.locale,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
    required this.onChanged,
    this.showError = false,
  });

  final bool value;
  final String label;
  final Locale locale;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;
  final ValueChanged<bool?> onChanged;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final phrases = _LegalConsentPhrases.forLocale(locale);
    final split = _ConsentLabelSplit.tryParse(
      label: label,
      termsText: phrases.terms,
      privacyText: phrases.privacy,
    );
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: colors.textStrong,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.34,
    );
    final linkStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: colors.accent,
      fontSize: 13,
      fontWeight: FontWeight.w800,
      height: 1.34,
      decoration: TextDecoration.underline,
      decorationColor: colors.accent.withValues(alpha: 0.7),
    );

    return Container(
      decoration: BoxDecoration(
        color: value
            ? colors.accentSoft.withValues(alpha: 0.44)
            : colors.surfaceGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: showError
              ? colors.danger.withValues(alpha: 0.55)
              : value
              ? colors.accent.withValues(alpha: 0.58)
              : colors.border.withValues(alpha: 0.8),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: colors.accent,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: split == null
                  ? Text(label, style: textStyle)
                  : Wrap(
                      children: [
                        Text(split.prefix, style: textStyle),
                        _InlineLegalLink(
                          text: split.terms,
                          style: linkStyle,
                          onTap: onOpenTerms,
                        ),
                        Text(split.between, style: textStyle),
                        _InlineLegalLink(
                          text: split.privacy,
                          style: linkStyle,
                          onTap: onOpenPrivacy,
                        ),
                        Text(split.suffix, style: textStyle),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketingConsentOption extends StatelessWidget {
  const _MarketingConsentOption({
    required this.value,
    required this.title,
    required this.onChanged,
  });

  final bool value;
  final String title;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: colors.accent,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textSoft,
                fontSize: 12.2,
                fontWeight: FontWeight.w600,
                height: 1.32,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegalStateLine extends StatelessWidget {
  const _LegalStateLine({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 14,
            color: isError ? colors.danger : colors.textMuted,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isError ? colors.danger : colors.textMuted,
              fontSize: 11.6,
              fontWeight: FontWeight.w600,
              height: 1.34,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineLegalLink extends StatelessWidget {
  const _InlineLegalLink({
    required this.text,
    required this.style,
    required this.onTap,
  });

  final String text;
  final TextStyle? style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Text(text, style: style),
      ),
    );
  }
}

class _ConsentLabelSplit {
  const _ConsentLabelSplit({
    required this.prefix,
    required this.terms,
    required this.between,
    required this.privacy,
    required this.suffix,
  });

  final String prefix;
  final String terms;
  final String between;
  final String privacy;
  final String suffix;

  static _ConsentLabelSplit? tryParse({
    required String label,
    required String termsText,
    required String privacyText,
  }) {
    final lower = label.toLowerCase();
    final lowerTerms = termsText.toLowerCase();
    final lowerPrivacy = privacyText.toLowerCase();
    final termsStart = lower.indexOf(lowerTerms);
    final privacyStart = lower.indexOf(lowerPrivacy);
    if (termsStart == -1 || privacyStart == -1 || termsStart >= privacyStart) {
      return null;
    }

    return _ConsentLabelSplit(
      prefix: label.substring(0, termsStart),
      terms: label.substring(termsStart, termsStart + termsText.length),
      between: label.substring(termsStart + termsText.length, privacyStart),
      privacy: label.substring(privacyStart, privacyStart + privacyText.length),
      suffix: label.substring(privacyStart + privacyText.length),
    );
  }
}

class _SignUpHighlights extends StatelessWidget {
  const _SignUpHighlights({
    required this.secureTitle,
    required this.secureSubtitle,
    required this.fastTitle,
    required this.fastSubtitle,
    required this.lovedTitle,
    required this.lovedSubtitle,
  });

  final String secureTitle;
  final String secureSubtitle;
  final String fastTitle;
  final String fastSubtitle;
  final String lovedTitle;
  final String lovedSubtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget item({
      required IconData icon,
      required String title,
      required String subtitle,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: isDark ? 0.4 : 0.88),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: colors.accent),
              const SizedBox(height: 5),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 11.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 10.6,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.accentSoft.withValues(alpha: isDark ? 0.18 : 0.52),
            colors.surfaceGlass.withValues(alpha: isDark ? 0.5 : 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.85)),
      ),
      child: Row(
        children: [
          item(
            icon: Icons.verified_user_outlined,
            title: secureTitle,
            subtitle: secureSubtitle,
          ),
          const SizedBox(width: 8),
          item(
            icon: Icons.bolt_rounded,
            title: fastTitle,
            subtitle: fastSubtitle,
          ),
          const SizedBox(width: 8),
          item(
            icon: Icons.favorite_border_rounded,
            title: lovedTitle,
            subtitle: lovedSubtitle,
          ),
        ],
      ),
    );
  }
}

class _LegalConsentPhrases {
  const _LegalConsentPhrases({required this.terms, required this.privacy});

  final String terms;
  final String privacy;

  static _LegalConsentPhrases forLocale(Locale locale) {
    switch (locale.languageCode.toLowerCase()) {
      case 'ru':
        return const _LegalConsentPhrases(
          terms: 'Условия использования',
          privacy: 'Политику конфиденциальности',
        );
      case 'de':
        return const _LegalConsentPhrases(
          terms: 'Nutzungsbedingungen',
          privacy: 'Datenschutzbestimmungen',
        );
      case 'es':
        return const _LegalConsentPhrases(
          terms: 'Términos de uso',
          privacy: 'Política de privacidad',
        );
      case 'fr':
        return const _LegalConsentPhrases(
          terms: 'conditions d\'utilisation',
          privacy: 'politique de confidentialité',
        );
      case 'it':
        return const _LegalConsentPhrases(
          terms: 'Termini di utilizzo',
          privacy: 'Informativa sulla privacy',
        );
      case 'pl':
        return const _LegalConsentPhrases(
          terms: 'Warunkami użytkowania',
          privacy: 'Polityką prywatności',
        );
      default:
        return const _LegalConsentPhrases(
          terms: 'Terms of Use',
          privacy: 'Privacy Policy',
        );
    }
  }
}

class _AuthInlineActions extends StatelessWidget {
  const _AuthInlineActions({
    required this.isSignUp,
    required this.switchPrompt,
    required this.switchAction,
    required this.forgotPasswordAction,
    required this.onForgotPassword,
    required this.onSwitchMode,
  });

  final bool isSignUp;
  final String switchPrompt;
  final String switchAction;
  final String forgotPasswordAction;
  final VoidCallback onForgotPassword;
  final VoidCallback onSwitchMode;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final compactButtonStyle = TextButton.styleFrom(
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      foregroundColor: colors.accent,
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    );

    final promptStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: colors.textMuted,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    if (isSignUp) {
      return Center(
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Text(switchPrompt, style: promptStyle),
            TextButton(
              onPressed: onSwitchMode,
              style: compactButtonStyle,
              child: Text(switchAction),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        TextButton(
          onPressed: onForgotPassword,
          style: compactButtonStyle,
          child: Text(forgotPasswordAction),
        ),
        const Spacer(),
        Text(switchPrompt, style: promptStyle),
        TextButton(
          onPressed: onSwitchMode,
          style: compactButtonStyle,
          child: Text(switchAction),
        ),
      ],
    );
  }
}
