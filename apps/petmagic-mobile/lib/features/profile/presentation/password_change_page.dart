import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_change_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_flow_widgets.dart';

class PasswordChangePage extends ConsumerStatefulWidget {
  const PasswordChangePage({super.key, required this.email});

  static const routePath = '/profile/settings/password-change';

  final String email;

  @override
  ConsumerState<PasswordChangePage> createState() => _PasswordChangePageState();
}

class _PasswordChangePageState extends ConsumerState<PasswordChangePage> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final email = widget.email.trim();
      ref.read(passwordChangeControllerProvider.notifier).reset(email: email);
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(passwordChangeControllerProvider);
    final controller = ref.read(passwordChangeControllerProvider.notifier);
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    _syncController(_codeController, state.code);
    _syncController(_passwordController, state.newPassword);
    _syncController(_confirmPasswordController, state.confirmPassword);

    return Scaffold(
      body: ProfileScreenBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        final router = GoRouter.of(context);
                        if (router.canPop()) {
                          router.pop();
                        }
                      },
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: colors.textStrong,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text.profileSettingsPasswordTitle,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            state.codeRequested
                                ? text.authPasswordResetCodeSubtitle
                                : text.profileSettingsPasswordSubtitle,
                            style: TextStyle(
                              color: colors.textSoft,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ProfileGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text.profileEmailLabel,
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.email,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  ProfileMessageCard(
                    message: _mapErrorMessage(state.errorMessage!, text),
                    tone: colors.danger,
                  ),
                ],
                if (state.successMessage != null) ...[
                  const SizedBox(height: 12),
                  ProfileMessageCard(
                    message: _mapSuccessMessage(state.successMessage!, text),
                    tone: colors.accent,
                  ),
                ],
                const SizedBox(height: 12),
                if (state.codeRequested)
                  ProfileGlassCard(
                    child: Column(
                      children: [
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
                if (state.codeRequested) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: state.isSaving
                          ? null
                          : () => controller.requestCode(),
                      child: Text(text.authPasswordResetResendAction),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final controller = ref.read(passwordChangeControllerProvider.notifier);
    final state = ref.read(passwordChangeControllerProvider);

    final succeeded = state.codeRequested
        ? await controller.confirmChange()
        : await controller.requestCode();

    if (!succeeded || !mounted) {
      return;
    }

    final nextState = ref.read(passwordChangeControllerProvider);
    if (nextState.successMessage == 'auth.password_reset_success') {
      FocusScope.of(context).unfocus();
    }
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

  String _mapSuccessMessage(String raw, AppLocalizations text) {
    switch (raw) {
      case 'auth.password_reset_code_sent':
        return text.authPasswordResetCodeSent;
      case 'auth.password_reset_success':
        return text.authPasswordResetSuccess;
      default:
        return raw;
    }
  }
}
