import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/profile/data/external_auth_repository.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/email_verification_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_reset_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_detail_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_flow_widgets.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/shared/widgets/motion.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_animated_button_child.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';

part 'auth_entry_consent.part.dart';
part 'auth_entry_content.part.dart';

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

class AuthEntryRouteArgs {
  const AuthEntryRouteArgs({this.initialEmail, this.redirectPath});

  final String? initialEmail;
  final String? redirectPath;
}

class RegisterEntryPage extends StatelessWidget {
  const RegisterEntryPage({super.key, this.redirectPath});

  static const routePath = '/register';
  final String? redirectPath;

  @override
  Widget build(BuildContext context) {
    return _AuthFlowPage(mode: _AuthMode.signUp, redirectPath: redirectPath);
  }
}

const int maxAuthRedirectPathLength = 1024;
final RegExp _authRedirectControlPattern = RegExp(r'[\x00-\x1F\x7F]');

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
  if (uri == null || uri.hasScheme || uri.hasAuthority) {
    return null;
  }

  return normalized;
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

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _obscureConfirmPassword = !_obscureConfirmPassword;
    });
  }

  void _setAcceptedTerms(bool value) {
    setState(() {
      _acceptedTerms = value;
      _consentErrorMessage = null;
    });
  }

  void _setReceiveUpdates(bool value) {
    setState(() {
      _receiveUpdates = value;
    });
  }

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
    final hasInternet = ref.watch(
      networkStatusControllerProvider.select((status) => status.hasInternet),
    );
    final legalDocumentsAsync = _isSignUp && hasInternet
        ? ref.watch(currentLegalDocumentsProvider(locale))
        : null;
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
    final showInlineTermsError = _hasConsentErrorCode(
      'auth.accept_terms_required',
    );
    final showInlineLegalError = _hasConsentErrorCode(
      'auth.legal_documents_unavailable',
    );
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
                  _AuthFlowContentSection(
                    page: this,
                    state: state,
                    text: text,
                    colors: colors,
                    isDark: isDark,
                    compactLayout: compactLayout,
                    isShortViewport: isShortViewport,
                    legalDocumentsAsync: legalDocumentsAsync,
                    confirmPasswordMismatch: confirmPasswordMismatch,
                    submitDisabled: submitDisabled,
                    showInlineTermsError: showInlineTermsError,
                    showInlineLegalError: showInlineLegalError,
                    socialProviders: socialProviders,
                    switchPrompt: switchPrompt,
                    switchAction: switchAction,
                    primaryAction: primaryAction,
                    controller: controller,
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

      if (!_acceptedTerms) {
        setState(() {
          _consentErrorMessage = 'auth.accept_terms_required';
        });
        return;
      }

      MobileLegalDocuments? legalDocuments;
      final cached = ref.read(currentLegalDocumentsProvider(locale));
      if (cached is AsyncData<MobileLegalDocuments>) {
        legalDocuments = cached.value;
      }

      if (legalDocuments != null &&
          (legalDocuments.termsOfUse.version.trim().isEmpty ||
              legalDocuments.privacyPolicy.version.trim().isEmpty)) {
        legalDocuments = null;
      }

      if (legalDocuments == null) {
        setState(() {
          _consentErrorMessage = 'auth.legal_documents_unavailable';
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
          normalizeProfileSuccessKey(nextState.successMessage) ==
              'auth.registration_pending_verification') {
        final email = nextState.email.trim();
        router.go(
          EmailVerificationPage.routePath,
          extra: EmailVerificationRouteArgs(
            email: email,
            startResendCooldown: true,
          ),
        );
      } else if (!_isSignUp &&
          normalizeProfileFeedbackKey(nextState.errorMessage) ==
              'auth.email_not_confirmed') {
        final email = nextState.email.trim();
        router.go(
          EmailVerificationPage.routePath,
          extra: EmailVerificationRouteArgs(email: email),
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
    return normalizeAuthRedirectPath(widget.redirectPath) ??
        TemplatesPage.routePath;
  }

  String _redirectQuery() {
    final redirectPath = normalizeAuthRedirectPath(widget.redirectPath);
    if (redirectPath == null) {
      return '';
    }

    return '?redirect=${Uri.encodeQueryComponent(redirectPath)}';
  }

  String _mapErrorMessage(String raw, AppLocalizations text) {
    return mapProfileFeedbackMessage(raw, text);
  }

  String? _mapSuccessMessage(String raw, AppLocalizations text) {
    return mapProfileSuccessMessage(raw, text);
  }

  void _openLegalDocument(ProfileSettingsDetailKind kind) {
    context.push(ProfileSettingsDetailPage.location(kind));
  }

  bool _hasConsentErrorCode(String key) {
    return normalizeProfileFeedbackKey(_consentErrorMessage) == key;
  }

  bool _isInlineConsentMessage(String raw) {
    final normalized = normalizeProfileFeedbackKey(raw);
    return normalized == 'auth.accept_terms_required' ||
        normalized == 'auth.legal_documents_unavailable';
  }
}
