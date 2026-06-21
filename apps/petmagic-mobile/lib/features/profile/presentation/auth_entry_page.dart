import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/features/profile/data/external_auth_repository.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/email_verification_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_reset_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_flow_widgets.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/legal_document_list_view.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/shared/widgets/motion.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_animated_button_child.dart';
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

@visibleForTesting
List<ExternalAuthProvider> authSocialProvidersForPlatform({
  required bool isIOS,
}) {
  return isIOS
      ? const [ExternalAuthProvider.apple, ExternalAuthProvider.google]
      : const [ExternalAuthProvider.google];
}

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
  GoRouter? _router;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router = GoRouter.of(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final controller = ref.read(profileControllerProvider.notifier);
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewport = MediaQuery.sizeOf(context);
    final isShortViewport = viewport.height <= 700;
    final isCompactViewport = viewport.height <= 760;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final legalDocumentsAsync = ref.watch(
      currentLegalDocumentsProvider(locale),
    );
    final legalDocumentsAvailable = legalDocumentsAsync.value != null;
    final compactLayout = _isSignUp || isCompactViewport;

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
    final showTopConsentError =
        _consentErrorMessage != null &&
        !_isInlineConsentMessage(_consentErrorMessage!);
    final showInlineTermsError =
        _consentErrorMessage == 'auth.accept_terms_required';
    final showInlineLegalError =
        legalDocumentsAsync.hasError ||
        _consentErrorMessage == 'auth.legal_documents_unavailable';
    final socialProviders = authSocialProvidersForPlatform(
      isIOS: !kIsWeb && Platform.isIOS,
    );
    final heroBottomSpacing = isShortViewport ? 8.0 : 12.0;

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
                padding: EdgeInsets.fromLTRB(
                  compactLayout ? 18 : 20,
                  compactLayout ? 2 : 4,
                  compactLayout ? 18 : 20,
                  isShortViewport ? 14 : (compactLayout ? 18 : 24),
                ),
                children: [
                  AuthHero(
                    title: title,
                    subtitle: subtitle,
                    isDark: isDark,
                    compact: compactLayout,
                  ),
                  SizedBox(height: heroBottomSpacing),
                  AnimatedSize(
                    duration: PetMotion.effectiveDuration(
                      context,
                      PetMotion.fast,
                    ),
                    curve: PetMotion.emphasized,
                    child: AnimatedSwitcher(
                      duration: PetMotion.effectiveDuration(
                        context,
                        PetMotion.fast,
                      ),
                      child: showTopConsentError
                          ? Padding(
                              key: ValueKey(_consentErrorMessage),
                              padding: EdgeInsets.only(
                                bottom: compactLayout ? 8 : 12,
                              ),
                              child: ErrorCard(
                                message: _mapErrorMessage(
                                  _consentErrorMessage!,
                                  text,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('no-consent-error'),
                            ),
                    ),
                  ),
                  AuthFormCard(
                    isDark: isDark,
                    compact: compactLayout,
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
                            compact: compactLayout,
                          ),
                          SizedBox(height: compactLayout ? 9 : 12),
                        ],
                        AuthField(
                          controller: _emailController,
                          hintText: text.profileEmailLabel,
                          prefixIcon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onChanged: controller.updateEmail,
                          enabled: !state.isSaving,
                          compact: compactLayout,
                        ),
                        SizedBox(height: compactLayout ? 9 : 12),
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
                          compact: compactLayout,
                          trailing: IconButton(
                            onPressed: state.isSaving
                                ? null
                                : () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                            icon: AnimatedSwitcher(
                              duration: PetMotion.effectiveDuration(
                                context,
                                PetMotion.fast,
                              ),
                              child: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                key: ValueKey(_obscurePassword),
                              ),
                            ),
                          ),
                        ),
                        if (_isSignUp) ...[
                          const SizedBox(height: 5),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                text.authPasswordRulesHint,
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 10.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 9),
                          AuthField(
                            controller: _confirmPasswordController,
                            hintText: text.authConfirmPasswordLabel,
                            prefixIcon: Icons.lock_person_outlined,
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            onChanged: controller.updateConfirmPassword,
                            enabled: !state.isSaving,
                            compact: compactLayout,
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
                              icon: AnimatedSwitcher(
                                duration: PetMotion.effectiveDuration(
                                  context,
                                  PetMotion.fast,
                                ),
                                child: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  key: ValueKey(_obscureConfirmPassword),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_isSignUp) ...[
                    const SizedBox(height: 10),
                    _TermsConsentOption(
                      value: _acceptedTerms,
                      label: text.authAcceptTermsLabel,
                      locale: Localizations.localeOf(context),
                      enabled: legalDocumentsAvailable && !state.isSaving,
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
                    if (showInlineTermsError) ...[
                      SizedBox(height: isShortViewport ? 4 : 5),
                      _LegalStateLine(
                        message: _mapErrorMessage(
                          'auth.accept_terms_required',
                          text,
                        ),
                        isError: true,
                      ),
                    ] else if (showInlineLegalError) ...[
                      SizedBox(height: isShortViewport ? 4 : 5),
                      _LegalStateLine(
                        message: text.authLegalUnavailable,
                        isError: true,
                      ),
                    ] else if (legalDocumentsAsync.isLoading) ...[
                      SizedBox(height: isShortViewport ? 4 : 5),
                      _LegalStateLine(message: text.authLegalLoading),
                    ],
                    SizedBox(height: isShortViewport ? 4 : 5),
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
                  SizedBox(height: compactLayout ? 8 : 14),
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
                      if (_isSignUp) {
                        if (GoRouter.of(context).canPop()) {
                          context.pop();
                          return;
                        }
                        context.go(AuthEntryPage.routePath);
                        return;
                      }

                      context.push(RegisterEntryPage.routePath);
                    },
                  ),
                  SizedBox(height: compactLayout ? 6 : 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: submitDisabled ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: Size.fromHeight(compactLayout ? 52 : 54),
                        padding: EdgeInsets.symmetric(
                          vertical: compactLayout ? 13 : 14,
                        ),
                        backgroundColor: colors.accent,
                        foregroundColor: isDark
                            ? const Color(0xFF03130C)
                            : Colors.white,
                        disabledBackgroundColor: isDark
                            ? colors.surfaceStrong.withValues(alpha: 0.78)
                            : const Color(0xFFD6E2DC),
                        disabledForegroundColor: colors.textMuted,
                        shadowColor: colors.accent.withValues(
                          alpha: isDark ? 0.22 : 0.28,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: state.isSaving ? 0 : 3,
                        textStyle: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(
                              fontSize: 13.6,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                      ),
                      child: PetMagicAnimatedButtonChild(
                        label: primaryAction,
                        loadingLabel: text.profileLoadingAction,
                        isLoading: state.isSaving,
                        loadingIndicatorColor: colors.textMuted,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: isShortViewport ? 10 : (compactLayout ? 12 : 18),
                  ),
                  AuthDivider(label: text.authOrContinueWith),
                  SizedBox(
                    height: isShortViewport ? 8 : (compactLayout ? 10 : 14),
                  ),
                  Column(
                    children: [
                      for (
                        var index = 0;
                        index < socialProviders.length;
                        index++
                      ) ...[
                        SizedBox(
                          width: double.infinity,
                          child: _SocialProviderButton(
                            provider: socialProviders[index],
                            compact: compactLayout,
                            isSaving: state.isSaving,
                            onPressed: _submitExternal,
                          ),
                        ),
                        if (index < socialProviders.length - 1)
                          SizedBox(
                            height: isShortViewport
                                ? 6
                                : (compactLayout ? 8 : 10),
                          ),
                      ],
                    ],
                  ),
                  SizedBox(
                    height: isShortViewport ? 10 : (compactLayout ? 12 : 18),
                  ),
                  LightPrivacyPanel(
                    title: text.authPrivacyTitle,
                    subtitle: text.authPrivacySubtitle,
                    compact: compactLayout,
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
    final router = _router;
    if (router == null) {
      return;
    }
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
    final router = _router;
    if (router == null) {
      return;
    }
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

  bool _isInlineConsentMessage(String raw) {
    return raw == 'auth.accept_terms_required' ||
        raw == 'auth.legal_documents_unavailable';
  }
}

class _SocialProviderButton extends StatelessWidget {
  const _SocialProviderButton({
    required this.provider,
    required this.compact,
    required this.isSaving,
    required this.onPressed,
  });

  final ExternalAuthProvider provider;
  final bool compact;
  final bool isSaving;
  final ValueChanged<ExternalAuthProvider> onPressed;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final isApple = provider == ExternalAuthProvider.apple;
    return SocialButton(
      icon: isApple ? SocialGlyph.apple() : SocialGlyph.google(),
      label: isApple ? text.authContinueWithApple : text.authContinueWithGoogle,
      compact: compact,
      onPressed: isSaving ? null : () => onPressed(provider),
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
    required this.enabled,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
    required this.onChanged,
    this.showError = false,
  });

  final bool value;
  final String label;
  final Locale locale;
  final bool enabled;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;
  final ValueChanged<bool?> onChanged;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phrases = _LegalConsentPhrases.forLocale(locale);
    final split = _ConsentLabelSplit.tryParse(
      label: label,
      termsText: phrases.terms,
      privacyText: phrases.privacy,
    );
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: enabled ? colors.textStrong : colors.textMuted,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.34,
    );
    final linkStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: enabled ? colors.accent : colors.textMuted,
      fontSize: 13,
      fontWeight: FontWeight.w800,
      height: 1.34,
      decoration: TextDecoration.underline,
      decorationColor: (enabled ? colors.accent : colors.textMuted).withValues(
        alpha: 0.7,
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? () => onChanged(!value) : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: value
                ? colors.accent.withValues(alpha: isDark ? 0.09 : 0.11)
                : colors.surfaceGlass.withValues(alpha: isDark ? 0.54 : 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: showError
                  ? colors.danger.withValues(alpha: 0.48)
                  : value
                  ? colors.accent.withValues(alpha: 0.52)
                  : colors.border.withValues(alpha: isDark ? 0.58 : 0.62),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(4, 5, 10, 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: value,
                onChanged: enabled ? onChanged : null,
                activeColor: colors.accent,
                checkColor: isDark ? const Color(0xFF03130C) : Colors.white,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide(
                  color: showError
                      ? colors.danger.withValues(alpha: 0.72)
                      : colors.border.withValues(alpha: 0.86),
                  width: 1.2,
                ),
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
                              onTap: enabled ? onOpenTerms : null,
                            ),
                            Text(split.between, style: textStyle),
                            _InlineLegalLink(
                              text: split.privacy,
                              style: linkStyle,
                              onTap: enabled ? onOpenPrivacy : null,
                            ),
                            Text(split.suffix, style: textStyle),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: colors.accent,
                checkColor: isDark ? const Color(0xFF03130C) : Colors.white,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide(
                  color: colors.border.withValues(alpha: 0.86),
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
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
          ),
        ),
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isError
            ? colors.danger.withValues(alpha: isDark ? 0.1 : 0.07)
            : colors.surfaceGlass.withValues(alpha: isDark ? 0.46 : 0.62),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError
              ? colors.danger.withValues(alpha: 0.2)
              : colors.border.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              size: 13,
              color: isError
                  ? colors.danger.withValues(alpha: 0.86)
                  : colors.textMuted,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isError
                    ? colors.danger.withValues(alpha: isDark ? 0.92 : 0.86)
                    : colors.textMuted,
                fontSize: 11.2,
                fontWeight: FontWeight.w600,
                height: 1.32,
              ),
            ),
          ),
        ],
      ),
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
  final VoidCallback? onTap;

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

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 400) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onForgotPassword,
                  style: compactButtonStyle,
                  child: Text(forgotPasswordAction),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    Text(
                      switchPrompt,
                      style: promptStyle,
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: onSwitchMode,
                      style: compactButtonStyle,
                      child: Text(switchAction),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 4,
          children: [
            TextButton(
              onPressed: onForgotPassword,
              style: compactButtonStyle,
              child: Text(forgotPasswordAction),
            ),
            Wrap(
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
          ],
        );
      },
    );
  }
}
