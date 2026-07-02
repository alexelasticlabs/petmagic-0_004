part of 'auth_entry_page.dart';

class _AuthFlowContentSection extends StatelessWidget {
  const _AuthFlowContentSection({
    required this.page,
    required this.state,
    required this.text,
    required this.colors,
    required this.isDark,
    required this.compactLayout,
    required this.isShortViewport,
    required this.legalDocumentsAsync,
    required this.confirmPasswordMismatch,
    required this.submitDisabled,
    required this.showInlineTermsError,
    required this.showInlineLegalError,
    required this.socialProviders,
    required this.switchPrompt,
    required this.switchAction,
    required this.primaryAction,
    required this.controller,
  });

  final _AuthFlowPageState page;
  final ProfileState state;
  final AppLocalizations text;
  final PetMagicColors colors;
  final bool isDark;
  final bool compactLayout;
  final bool isShortViewport;
  final AsyncValue<MobileLegalDocuments>? legalDocumentsAsync;
  final bool confirmPasswordMismatch;
  final bool submitDisabled;
  final bool showInlineTermsError;
  final bool showInlineLegalError;
  final List<ExternalAuthProvider> socialProviders;
  final String switchPrompt;
  final String switchAction;
  final String primaryAction;
  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AuthFormCard(
          isDark: isDark,
          compact: compactLayout,
          child: Column(
            children: [
              if (page._isSignUp) ...[
                AuthField(
                  controller: page._displayNameController,
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
                controller: page._emailController,
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
                controller: page._passwordController,
                hintText: text.profilePasswordLabel,
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: page._obscurePassword,
                textInputAction: page._isSignUp
                    ? TextInputAction.next
                    : TextInputAction.done,
                onChanged: controller.updatePassword,
                enabled: !state.isSaving,
                compact: compactLayout,
                trailing: IconButton(
                  onPressed: state.isSaving
                      ? null
                      : page._togglePasswordVisibility,
                  icon: AnimatedSwitcher(
                    duration: PetMotion.effectiveDuration(
                      context,
                      PetMotion.fast,
                    ),
                    child: Icon(
                      page._obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      key: ValueKey(page._obscurePassword),
                    ),
                  ),
                ),
              ),
              if (page._isSignUp) ...[
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      text.authPasswordRulesHint,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                AuthField(
                  controller: page._confirmPasswordController,
                  hintText: text.authConfirmPasswordLabel,
                  prefixIcon: Icons.lock_person_outlined,
                  obscureText: page._obscureConfirmPassword,
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
                        : page._toggleConfirmPasswordVisibility,
                    icon: AnimatedSwitcher(
                      duration: PetMotion.effectiveDuration(
                        context,
                        PetMotion.fast,
                      ),
                      child: Icon(
                        page._obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        key: ValueKey(page._obscureConfirmPassword),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (page._isSignUp) ...[
          const SizedBox(height: 10),
          _TermsConsentOption(
            value: page._acceptedTerms,
            label: text.authAcceptTermsLabel,
            enabled: !state.isSaving,
            onOpenTerms: () =>
                page._openLegalDocument(ProfileSettingsDetailKind.terms),
            onOpenPrivacy: () =>
                page._openLegalDocument(ProfileSettingsDetailKind.privacy),
            showError: page._hasConsentErrorCode('auth.accept_terms_required'),
            onChanged: (value) => page._setAcceptedTerms(value ?? false),
          ),
          if (showInlineTermsError) ...[
            SizedBox(height: isShortViewport ? 4 : 5),
            _LegalStateLine(
              message: page._mapErrorMessage(
                'auth.accept_terms_required',
                text,
              ),
              isError: true,
            ),
          ] else if (showInlineLegalError) ...[
            SizedBox(height: isShortViewport ? 4 : 5),
            _LegalStateLine(message: text.authLegalUnavailable, isError: true),
          ] else if (legalDocumentsAsync?.isLoading == true) ...[
            SizedBox(height: isShortViewport ? 4 : 5),
            _LegalStateLine(message: text.authLegalLoading),
          ],
          SizedBox(height: isShortViewport ? 4 : 5),
          _MarketingConsentOption(
            value: page._receiveUpdates,
            title: text.authReceiveUpdatesLabel,
            onChanged: (value) => page._setReceiveUpdates(value ?? false),
          ),
        ],
        SizedBox(height: compactLayout ? 8 : 14),
        _AuthInlineActions(
          isSignUp: page._isSignUp,
          switchPrompt: switchPrompt,
          switchAction: switchAction,
          forgotPasswordAction: text.authForgotPasswordAction,
          onForgotPassword: () {
            final email = page._emailController.text.trim();
            context.go(
              PasswordResetPage.routePath,
              extra: email.isEmpty
                  ? null
                  : PasswordResetRouteArgs(initialEmail: email),
            );
          },
          onSwitchMode: () {
            final redirectQuery = page._redirectQuery();
            if (page._isSignUp) {
              if (GoRouter.of(context).canPop()) {
                context.pop();
                return;
              }
              context.go('${AuthEntryPage.routePath}$redirectQuery');
              return;
            }

            context.push('${RegisterEntryPage.routePath}$redirectQuery');
          },
        ),
        SizedBox(height: compactLayout ? 6 : 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: submitDisabled ? null : page._submit,
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(compactLayout ? 52 : 54),
              padding: EdgeInsets.symmetric(vertical: compactLayout ? 13 : 14),
              backgroundColor: colors.accent,
              foregroundColor: isDark ? const Color(0xFF03130C) : Colors.white,
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
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 14,
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
        SizedBox(height: isShortViewport ? 10 : (compactLayout ? 12 : 18)),
        AuthDivider(label: text.authOrContinueWith),
        SizedBox(height: isShortViewport ? 8 : (compactLayout ? 10 : 14)),
        Column(
          children: [
            for (var index = 0; index < socialProviders.length; index++) ...[
              SizedBox(
                width: double.infinity,
                child: _SocialProviderButton(
                  provider: socialProviders[index],
                  compact: compactLayout,
                  isSaving: state.isSaving,
                  onPressed: page._submitExternal,
                ),
              ),
              if (index < socialProviders.length - 1)
                SizedBox(
                  height: isShortViewport ? 6 : (compactLayout ? 8 : 10),
                ),
            ],
          ],
        ),
        SizedBox(height: isShortViewport ? 10 : (compactLayout ? 12 : 18)),
        LightPrivacyPanel(
          title: text.authPrivacyTitle,
          subtitle: text.authPrivacySubtitle,
          compact: compactLayout,
        ),
      ],
    );
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
