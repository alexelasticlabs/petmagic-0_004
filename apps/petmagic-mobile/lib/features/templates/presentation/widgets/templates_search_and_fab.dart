import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/shared/widgets/pressable_scale.dart';

class TemplatesSearchField extends StatelessWidget {
  const TemplatesSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.focusNode,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return TextField(
      key: const ValueKey('templates-search-field'),
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: TextStyle(
        color: colors.textStrong,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: text.searchTemplates,
        hintStyle: TextStyle(
          color: colors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: colors.textMuted,
          size: 15,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    );
  }
}

class FloatingRandomTemplateButton extends StatelessWidget {
  const FloatingRandomTemplateButton({
    super.key,
    required this.isLoading,
    required this.isEnabled,
    required this.onPressed,
  });

  final bool isLoading;
  final bool isEnabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final avoidBlur = PerformanceGuard.shouldAvoidBlur(context);
    final enabled = isEnabled && !isLoading;

    return RepaintBoundary(
      child: Tooltip(
        message: text.randomTemplateAction,
        child: Semantics(
          button: true,
          enabled: enabled,
          label: text.randomTemplateAction,
          child: AnimatedOpacity(
            duration: AppTheme.motionFast,
            opacity: enabled ? 1 : 0.4,
            child: PressableScale(
              enabled: enabled,
              onTap: enabled ? onPressed : null,
              haptic: PressableScaleHaptic.selection,
              borderRadius: BorderRadius.circular(24),
              scaleDown: 0.96,
              child: ClipOval(
                child: _FloatingRandomTemplateSurface(
                  isLight: isLight,
                  colors: colors,
                  avoidBlur: avoidBlur,
                  isLoading: isLoading,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingRandomTemplateSurface extends StatelessWidget {
  const _FloatingRandomTemplateSurface({
    required this.isLight,
    required this.colors,
    required this.avoidBlur,
    required this.isLoading,
  });

  final bool isLight;
  final PetMagicColors colors;
  final bool avoidBlur;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final content = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceGlass.withValues(alpha: isLight ? 0.92 : 0.74),
        border: Border.all(
          color: colors.accent.withValues(alpha: isLight ? 0.72 : 0.64),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: colors.accent.withValues(alpha: 0.22),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: SizedBox(
        key: const ValueKey('templates-random-floating-button'),
        width: 48,
        height: 48,
        child: Center(
          child: AnimatedSwitcher(
            duration: AppTheme.motionFast,
            child: isLoading
                ? SizedBox(
                    key: const ValueKey('random-template-loading'),
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator.adaptive(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                    ),
                  )
                : Icon(
                    Icons.casino_rounded,
                    key: const ValueKey('random-template-icon'),
                    size: 22,
                    color: isLight ? colors.accent : colors.textStrong,
                  ),
          ),
        ),
      ),
    );

    if (avoidBlur) {
      return content;
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: content,
    );
  }
}
