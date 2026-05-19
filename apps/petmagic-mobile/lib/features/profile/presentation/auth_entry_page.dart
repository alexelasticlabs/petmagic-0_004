import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/data/external_auth_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_reset_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_flow_widgets.dart';
import 'package:petmagic_mobile/features/startup/presentation/guest_welcome_page.dart';
import 'package:petmagic_mobile/features/startup/presentation/onboarding_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';

class AuthEntryPage extends StatelessWidget {
  const AuthEntryPage({super.key, this.initialEmail});

  static const routePath = '/auth';

  final String? initialEmail;

  @override
  Widget build(BuildContext context) {
    return _AuthFlowPage(mode: _AuthMode.signIn, initialEmail: initialEmail);
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
  const _AuthFlowPage({required this.mode, this.initialEmail});

  final _AuthMode mode;
  final String? initialEmail;

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
    Future.microtask(() {
      ref
          .read(profileControllerProvider.notifier)
          .initialize(initialEmail: widget.initialEmail?.trim() ?? '');
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

    _syncController(_displayNameController, state.displayName);
    _syncController(_emailController, state.email);
    _syncController(_passwordController, state.password);
    _syncController(_confirmPasswordController, state.confirmPassword);

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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                          AuthHero(
                            title: title,
                            subtitle: subtitle,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 2),
                          if (state.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ErrorCard(
                                message: _mapErrorMessage(
                                  state.errorMessage!,
                                  text,
                                ),
                              ),
                            ),
                          if (_consentErrorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ErrorCard(
                                message: _mapErrorMessage(
                                  _consentErrorMessage!,
                                  text,
                                ),
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
                                  trailing: IconButton(
                                    onPressed: () {
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
                                  const SizedBox(height: 8),
                                  AuthField(
                                    controller: _confirmPasswordController,
                                    hintText: text.authConfirmPasswordLabel,
                                    prefixIcon: Icons.lock_person_outlined,
                                    obscureText: _obscureConfirmPassword,
                                    textInputAction: TextInputAction.done,
                                    onChanged: controller.updateConfirmPassword,
                                    trailing: IconButton(
                                      onPressed: () {
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
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      text.authPasswordRulesHint,
                                      style: TextStyle(
                                        color: colors.textMuted,
                                        fontSize: 10.4,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_isSignUp) ...[
                            const SizedBox(height: 12),
                            _ConsentOption(
                              value: _acceptedTerms,
                              title: text.authAcceptTermsLabel,
                              onChanged: (value) {
                                setState(() {
                                  _acceptedTerms = value ?? false;
                                  _consentErrorMessage = null;
                                });
                              },
                            ),
                            const SizedBox(height: 6),
                            _ConsentOption(
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
                              context.go(
                                '${PasswordResetPage.routePath}$query',
                              );
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
                              onPressed: state.isSaving ? null : _submit,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
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
                          Row(
                            children: [
                              Expanded(
                                child: SocialButton(
                                  icon: SocialGlyph.google(),
                                  label: text.authGoogleShortLabel,
                                  onPressed: state.isSaving
                                      ? null
                                      : () => _submitExternal(
                                          ExternalAuthProvider.google,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SocialButton(
                                  icon: SocialGlyph.apple(),
                                  label: text.authAppleShortLabel,
                                  onPressed: state.isSaving
                                      ? null
                                      : () => _submitExternal(
                                          ExternalAuthProvider.apple,
                                        ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (isDark)
                            DarkTrustPanel(
                              secureTitle: text.authSecurePrivateTitle,
                              secureSubtitle: text.authSecurePrivateSubtitle,
                              fastTitle: text.authFastEasyTitle,
                              fastSubtitle: text.authFastEasySubtitle,
                              lovedTitle: text.authLovedByPetsTitle,
                              lovedSubtitle: text.authLovedByPetsSubtitle,
                            )
                          else
                            LightPrivacyPanel(
                              title: text.authPrivacyTitle,
                              subtitle: text.authPrivacySubtitle,
                            ),
                        ],
                      ),
                    ),
                  );
                },
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
      if (!_acceptedTerms) {
        setState(() {
          _consentErrorMessage = 'auth.accept_terms_required';
        });
        return;
      }
      await controller.register(
        termsOfUseAccepted: _acceptedTerms,
        marketingEmailsEnabled: _receiveUpdates,
      );
    } else {
      await controller.login();
    }

    final nextState = ref.read(profileControllerProvider);
    if (!nextState.isAuthenticated || !context.mounted) {
      return;
    }
    router.go(TemplatesPage.routePath);
  }

  Future<void> _submitExternal(ExternalAuthProvider provider) async {
    final controller = ref.read(profileControllerProvider.notifier);
    final router = GoRouter.of(context);
    await controller.authenticateWithProvider(provider);

    final nextState = ref.read(profileControllerProvider);
    if (!nextState.isAuthenticated || !context.mounted) {
      return;
    }

    router.go(TemplatesPage.routePath);
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

    context.go(
      launchState.hasSeenOnboarding
          ? GuestWelcomePage.routePath
          : OnboardingPage.routePath,
    );
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

  String _mapErrorMessage(String raw, AppLocalizations text) {
    switch (raw) {
      case 'auth.password_mismatch':
        return text.authPasswordMismatch;
      case 'auth.password_too_short':
        return text.authPasswordTooShort;
      case 'auth.accept_terms_required':
        return text.authAcceptTermsRequired;
      case 'auth.external_cancelled':
        return text.authExternalCancelled;
      case 'auth.external_callback_failed':
        return text.authExternalCallbackFailed;
      case 'auth.external_launch_failed':
        return text.authExternalLaunchFailed;
      case 'auth.external_timed_out':
        return text.authExternalTimedOut;
      case 'auth.external_ticket_invalid':
        return text.authExternalSessionExpired;
      case 'auth.external_not_configured':
      case 'auth.external_token_invalid':
      case 'auth.external_invalid':
        return text.authExternalFailed;
      default:
        return raw;
    }
  }
}

class _ConsentOption extends StatelessWidget {
  const _ConsentOption({
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

    return Material(
      color: colors.surfaceGlass,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onChanged(!value),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: colors.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textStrong,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
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
