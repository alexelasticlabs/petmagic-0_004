import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_reset_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_flow_widgets.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';

class PasswordResetPage extends ConsumerStatefulWidget {
  const PasswordResetPage({super.key, this.initialEmail});

  static const routePath = '/password-reset';

  final String? initialEmail;

  @override
  ConsumerState<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends ConsumerState<PasswordResetPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) {
        return;
      }

      final initialEmail = widget.initialEmail?.trim() ?? '';
      ref
          .read(passwordResetControllerProvider.notifier)
          .reset(email: initialEmail);
      _syncControllers(ref.read(passwordResetControllerProvider));
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(passwordResetControllerProvider);
    final controller = ref.read(passwordResetControllerProvider.notifier);
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    ref.listen(passwordResetControllerProvider, (previous, next) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final title = state.codeRequested
        ? text.authPasswordResetCodeTitle
        : text.authPasswordResetTitle;
    final subtitle = state.codeRequested
        ? text.authPasswordResetCodeSubtitle
        : text.authPasswordResetSubtitle;

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
                        onPressed: _goToAuth,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  AuthHero(title: title, subtitle: subtitle, isDark: isDark),
                  const SizedBox(height: 6),
                  AuthFormCard(
                    isDark: isDark,
                    child: Column(
                      children: [
                        AuthField(
                          controller: _emailController,
                          hintText: text.profileEmailLabel,
                          prefixIcon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: state.codeRequested
                              ? TextInputAction.next
                              : TextInputAction.done,
                          onChanged: controller.updateEmail,
                        ),
                        if (state.codeRequested) ...[
                          const SizedBox(height: 8),
                          AuthField(
                            controller: _codeController,
                            hintText: text.authPasswordResetCodeLabel,
                            prefixIcon: Icons.mark_email_read_outlined,
                            textInputAction: TextInputAction.next,
                            onChanged: controller.updateCode,
                          ),
                          const SizedBox(height: 8),
                          AuthField(
                            controller: _passwordController,
                            hintText: text.profilePasswordLabel,
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            onChanged: controller.updateNewPassword,
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: state.isSaving ? null : _submit,
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
                            : state.codeRequested
                            ? text.authPasswordResetConfirmAction
                            : text.authPasswordResetRequestAction,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: state.isSaving
                          ? null
                          : state.codeRequested
                          ? () => controller.requestReset()
                          : _goToAuth,
                      child: Text(
                        state.codeRequested
                            ? text.authPasswordResetResendAction
                            : text.profileSignInAction,
                      ),
                    ),
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
    final controller = ref.read(passwordResetControllerProvider.notifier);
    final text = AppLocalizations.of(context);
    final state = ref.read(passwordResetControllerProvider);

    final succeeded = state.codeRequested
        ? await controller.confirmReset()
        : await controller.requestReset();

    if (!succeeded || !mounted) {
      return;
    }

    final nextState = ref.read(passwordResetControllerProvider);
    if (nextState.successMessage == 'auth.password_reset_success') {
      PetMagicToast.show(
        context,
        message: text.authPasswordResetSuccess,
        tone: PetMagicToastTone.success,
      );
      _goToAuth();
    }
  }

  void _goToAuth() {
    final email = ref.read(passwordResetControllerProvider).email.trim();
    final query = email.isEmpty
        ? ''
        : '?email=${Uri.encodeQueryComponent(email)}';
    context.go('${AuthEntryPage.routePath}$query');
  }

  void _syncControllers(PasswordResetState state) {
    _syncController(_emailController, state.email);
    _syncController(_codeController, state.code);
    _syncController(_passwordController, state.newPassword);
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

  String _mapErrorMessage(String raw, AppLocalizations text) {
    return mapProfileFeedbackMessage(raw, text);
  }

  String? _mapSuccessMessage(String raw, AppLocalizations text) {
    switch (raw) {
      case 'auth.password_reset_code_sent':
        return text.authPasswordResetCodeSent;
      case 'auth.password_reset_success':
        return text.authPasswordResetSuccess;
      default:
        return null;
    }
  }
}
