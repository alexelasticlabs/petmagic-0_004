import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  static const routePath = '/profile';

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
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

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.backgroundTop, colors.backgroundBottom],
        ),
      ),
      child: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : RefreshIndicator.adaptive(
                onRefresh: controller.initialize,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Text(
                      text.profileTitle,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      text.profileSubtitle,
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 18),
                      _MessageCard(
                        message: state.errorMessage!,
                        tone: colors.danger,
                      ),
                    ],
                    if (state.successMessage == 'logout') ...[
                      const SizedBox(height: 18),
                      _MessageCard(
                        message: text.profileSignedOut,
                        tone: colors.accent,
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (!state.isAuthenticated) ...[
                      _GlassCard(
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
                            FilledButton(
                              onPressed: state.isSaving
                                  ? null
                                  : controller.login,
                              child: Text(
                                state.isSaving
                                    ? text.profileLoadingAction
                                    : text.profileSignInAction,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (state.profile != null) ...[
                      _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _AvatarBadge(
                                  imageUrl: state.profile!.avatar?.url,
                                  fallbackLabel:
                                      state.profile!.displayName ??
                                      state.profile!.email,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        state.profile!.displayName
                                                    ?.trim()
                                                    .isNotEmpty ==
                                                true
                                            ? state.profile!.displayName!
                                            : state.profile!.email,
                                        style: TextStyle(
                                          color: colors.textStrong,
                                          fontSize: 21,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        state.profile!.email,
                                        style: TextStyle(
                                          color: colors.textMuted,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _Pill(
                                            label: state.profile!.isPremium
                                                ? text.premiumLabel
                                                : text.freeLabel,
                                          ),
                                          _Pill(
                                            label: state.profile!.emailConfirmed
                                                ? text.profileEmailConfirmed
                                                : text.profileEmailPending,
                                          ),
                                          for (final role
                                              in state.profile!.roles)
                                            _Pill(label: role),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: state.isSaving
                                        ? null
                                        : controller.uploadAvatar,
                                    icon: const Icon(
                                      Icons.add_a_photo_outlined,
                                    ),
                                    label: Text(
                                      state.isSaving
                                          ? text.profileLoadingAction
                                          : text.profileAvatarUpload,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed:
                                        state.isSaving ||
                                            state.profile!.avatar == null
                                        ? null
                                        : controller.removeAvatar,
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                    ),
                                    label: Text(text.profileAvatarRemove),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: state.isSaving
                                  ? null
                                  : controller.logout,
                              child: Text(text.profileSignOutAction),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
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
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.tone});

  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          message,
          style: TextStyle(
            color: colors.textStrong,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.imageUrl, required this.fallbackLabel});

  final String? imageUrl;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final initials = fallbackLabel.isNotEmpty
        ? fallbackLabel.trim().substring(0, 1).toUpperCase()
        : '?';

    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceStrong,
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? Image.network(imageUrl!, fit: BoxFit.cover)
          : Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
