import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_change_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_flow_widgets.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';

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
      if (!mounted) {
        return;
      }

      final email = widget.email.trim();
      ref.read(passwordChangeControllerProvider.notifier).reset(email: email);
      _syncControllers(ref.read(passwordChangeControllerProvider));
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

    ref.listen(passwordChangeControllerProvider, (previous, next) {
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
      body: ProfileScreenBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
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
              // Индикатор шагов
              _PasswordChangeStepIndicator(
                currentStep: state.codeRequested ? 1 : 0,
              ),
              const SizedBox(height: 16),
              // Email карточка
              ProfileGlassCard(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        Icons.alternate_email_rounded,
                        size: 18,
                        color: colors.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
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
                          const SizedBox(height: 3),
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
                  ],
                ),
              ),
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

  void _syncControllers(PasswordChangeState state) {
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

class _PasswordChangeStepIndicator extends StatelessWidget {
  const _PasswordChangeStepIndicator({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    const steps = [
      (label: 'Запрос кода', icon: Icons.mark_email_unread_outlined),
      (label: 'Новый пароль', icon: Icons.lock_reset_rounded),
    ];

    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: _StepPill(
              index: i,
              label: steps[i].label,
              icon: steps[i].icon,
              state: i < currentStep
                  ? _StepState.done
                  : i == currentStep
                  ? _StepState.active
                  : _StepState.upcoming,
            ),
          ),
          if (i < steps.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 24,
                height: 2,
                decoration: BoxDecoration(
                  color: currentStep > 0
                      ? colors.accent
                      : colors.border.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

enum _StepState { done, active, upcoming }

class _StepPill extends StatelessWidget {
  const _StepPill({
    required this.index,
    required this.label,
    required this.icon,
    required this.state,
  });

  final int index;
  final String label;
  final IconData icon;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isDone = state == _StepState.done;
    final isActive = state == _StepState.active;

    final iconColor = isDone || isActive ? colors.accent : colors.textMuted;
    final bgColor = isDone || isActive
        ? colors.accent.withValues(alpha: 0.13)
        : colors.border.withValues(alpha: 0.2);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? colors.accent.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isDone ? Icons.check_rounded : icon, size: 15, color: iconColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDone || isActive
                    ? colors.textStrong
                    : colors.textMuted,
                fontSize: 12.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
