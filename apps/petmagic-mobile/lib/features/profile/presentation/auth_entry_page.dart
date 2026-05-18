import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';

class AuthEntryPage extends ConsumerStatefulWidget {
  const AuthEntryPage({super.key});

  static const routePath = '/auth';

  @override
  ConsumerState<AuthEntryPage> createState() => _AuthEntryPageState();
}

class _AuthEntryPageState extends ConsumerState<AuthEntryPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(profileControllerProvider.notifier).initialize(),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final controller = ref.read(profileControllerProvider.notifier);
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    if (_emailController.text != state.email) {
      _emailController.value = _emailController.value.copyWith(
        text: state.email,
        selection: TextSelection.collapsed(offset: state.email.length),
      );
    }

    if (_passwordController.text != state.password) {
      _passwordController.value = _passwordController.value.copyWith(
        text: state.password,
        selection: TextSelection.collapsed(offset: state.password.length),
      );
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.backgroundTop, colors.backgroundBottom],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton.outlined(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      text.authEntryTitle,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  text.authEntrySubtitle,
                  style: TextStyle(
                    color: colors.textSoft,
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 24),
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: colors.danger.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          state.errorMessage!,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceGlass,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: colors.border),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow,
                        blurRadius: 24,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text.profileSignInTitle,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          text.profileSignInHint,
                          style: TextStyle(
                            color: colors.textMuted,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: controller.updateEmail,
                          decoration: InputDecoration(
                            labelText: text.profileEmailLabel,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          onChanged: controller.updatePassword,
                          decoration: InputDecoration(
                            labelText: text.profilePasswordLabel,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: state.isSaving
                                ? null
                                : () async {
                                    await controller.login();
                                    final nextState = ref.read(
                                      profileControllerProvider,
                                    );
                                    if (!nextState.isAuthenticated ||
                                        !context.mounted) {
                                      return;
                                    }
                                    ref
                                        .read(
                                          appLaunchControllerProvider.notifier,
                                        )
                                        .markSignedIn();
                                    context.go(TemplatesPage.routePath);
                                  },
                            child: Text(
                              state.isSaving
                                  ? text.profileLoadingAction
                                  : text.profileSignInAction,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
