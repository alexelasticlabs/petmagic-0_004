import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';

class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: -56,
            top: 76,
            child: BlurOrb(
              size: 150,
              color: colors.accent.withValues(alpha: isDark ? 0.06 : 0.07),
            ),
          ),
          Positioned(
            right: -64,
            top: 126,
            child: BlurOrb(
              size: 170,
              color: colors.gold.withValues(alpha: isDark ? 0.05 : 0.06),
            ),
          ),
          Positioned(
            right: 24,
            top: 98,
            child: Icon(
              Icons.pets_rounded,
              size: 22,
              color: colors.accent.withValues(alpha: isDark ? 0.18 : 0.22),
            ),
          ),
          Positioned(
            left: 38,
            top: 124,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: colors.gold.withValues(alpha: isDark ? 0.22 : 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthHero extends StatelessWidget {
  const AuthHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isDark,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool isDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final titleStyle = Theme.of(context).textTheme.headlineMedium;
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 360;
        final imageHeight = compact
            ? (narrow ? 126.0 : 140.0)
            : (narrow ? 172.0 : 196.0);
        return ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: compact ? 152 : (narrow ? 190 : 214),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: compact ? 13 : (narrow ? 12 : 11),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: compact ? 6 : (narrow ? 12 : 20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AuthWordmark(isDark: isDark, compact: compact),
                      SizedBox(height: compact ? 6 : 10),
                      Text(
                        title,
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.visible,
                        style: titleStyle?.copyWith(
                          fontSize: compact ? 18.5 : (narrow ? 20 : 22),
                          height: compact ? 1.04 : 1.08,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                          color: colors.textStrong,
                        ),
                      ),
                      SizedBox(height: compact ? 5 : 8),
                      Text(
                        subtitle,
                        maxLines: compact ? 2 : 3,
                        overflow: TextOverflow.visible,
                        style: subtitleStyle?.copyWith(
                          fontSize: compact ? 11.1 : (narrow ? 11.8 : 12.6),
                          height: compact ? 1.28 : 1.36,
                          fontWeight: FontWeight.w600,
                          color: colors.textSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: compact ? 2 : (narrow ? 0 : 6)),
              Expanded(
                flex: compact ? 7 : (narrow ? 8 : 9),
                child: SizedBox(
                  height: imageHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                colors.gold.withValues(
                                  alpha: isDark ? 0.1 : 0.13,
                                ),
                                colors.accent.withValues(
                                  alpha: isDark ? 0.18 : 0.22,
                                ),
                                colors.accent.withValues(alpha: 0.06),
                                Colors.transparent,
                              ],
                              stops: const [0.08, 0.42, 0.76, 1],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: compact ? 8 : (narrow ? 12 : 18),
                        right: compact ? 8 : (narrow ? 12 : 18),
                        top: compact ? 34 : (narrow ? 48 : 52),
                        bottom: compact ? 4 : 8,
                        child: Transform.rotate(
                          angle: -0.1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              color: colors.surfaceGlass.withValues(
                                alpha: isDark ? 0.24 : 0.68,
                              ),
                              border: Border.all(
                                color: colors.border.withValues(
                                  alpha: isDark ? 0.45 : 0.55,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: compact ? -8 : (narrow ? -12 : -16),
                        right: compact ? -8 : (narrow ? -12 : -16),
                        top: compact ? 26 : (narrow ? 38 : 42),
                        bottom: compact ? -36 : (narrow ? -46 : -68),
                        child: Transform.scale(
                          scale: compact ? 1.0 : (narrow ? 1.06 : 1.12),
                          alignment: Alignment.bottomCenter,
                          child: Image.asset(
                            'assets/auth/petmagic-auth-hero.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AuthWordmark extends StatelessWidget {
  const AuthWordmark({super.key, required this.isDark, this.compact = false});

  final bool isDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: compact ? 42 : 58,
          height: compact ? 42 : 58,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.22),
                      width: 1.1,
                    ),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accent.withValues(alpha: 0.08),
                ),
                child: Padding(
                  padding: EdgeInsets.all(compact ? 8 : 11),
                  child: Icon(
                    Icons.pets_rounded,
                    color: colors.accent,
                    size: compact ? 20 : 26,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 5 : 8),
        Text(
          'PetMagic',
          style: GoogleFonts.comfortaa(
            fontSize: compact ? 20 : 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            color: isDark ? colors.textStrong : const Color(0xFF10234A),
          ),
        ),
      ],
    );
  }
}

class AuthFormCard extends StatelessWidget {
  const AuthFormCard({
    super.key,
    required this.child,
    required this.isDark,
    this.compact = false,
  });

  final Widget child;
  final bool isDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xB8181F26) : const Color(0xB8FFFFFF),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0x40789687) : const Color(0x8CB4C8BE),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : const Color(0x1A1F2D3D),
                blurRadius: compact ? 24 : 32,
                offset: Offset(0, compact ? 8 : 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    required this.onChanged,
    this.trailing,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.errorText,
    this.compact = false,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final ValueChanged<String> onChanged;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final String? errorText;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final labelStyle = Theme.of(context).textTheme.bodyMedium;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputFill = enabled
        ? (isDark ? const Color(0xFF141C24) : const Color(0xFFFCFEFF))
        : colors.surfaceStrong.withValues(alpha: isDark ? 0.62 : 0.5);
    final iconColor = enabled ? colors.textSoft : colors.textMuted;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      style: labelStyle?.copyWith(
        color: enabled ? colors.textStrong : colors.textMuted,
        fontSize: compact ? 13.2 : 13.6,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        constraints: BoxConstraints(minHeight: compact ? 50 : 54),
        errorText: errorText,
        hintText: hintText,
        hintStyle: labelStyle?.copyWith(
          color: colors.textMuted.withValues(alpha: isDark ? 0.82 : 0.72),
          fontSize: compact ? 12.6 : 13,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 6),
          child: Icon(prefixIcon, color: iconColor, size: 20),
        ),
        prefixIconConstraints: BoxConstraints(
          minWidth: 44,
          minHeight: compact ? 50 : 54,
        ),
        suffixIcon: trailing,
        suffixIconColor: iconColor,
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: isDark ? const Color(0x665F7D70) : const Color(0xB6BAC8D2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.accent, width: 1.55),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: colors.border.withValues(alpha: isDark ? 0.38 : 0.45),
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: colors.danger.withValues(alpha: 0.64),
            width: 1.2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: colors.danger.withValues(alpha: 0.9),
            width: 1.4,
          ),
        ),
        errorStyle: TextStyle(
          color: colors.danger.withValues(alpha: isDark ? 0.92 : 0.86),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: compact ? 13 : 15,
        ),
      ),
    );
  }
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Row(
      children: [
        Expanded(
          child: Divider(
            color: colors.border.withValues(alpha: 0.58),
            thickness: 0.8,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: TextStyle(
              color: colors.textMuted.withValues(alpha: 0.86),
              fontSize: 11.6,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: colors.border.withValues(alpha: 0.58),
            thickness: 0.8,
          ),
        ),
      ],
    );
  }
}

class SocialButton extends StatelessWidget {
  const SocialButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.compact = false,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size.fromHeight(compact ? 48 : 52),
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: compact ? 11 : 13,
        ),
        side: BorderSide(
          color: isDark
              ? colors.border.withValues(alpha: 0.9)
              : colors.border.withValues(alpha: 0.72),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        foregroundColor: colors.textStrong,
        disabledForegroundColor: colors.textMuted,
        backgroundColor: isDark
            ? const Color(0xCC111922)
            : colors.surface.withValues(alpha: 0.92),
        disabledBackgroundColor: colors.surfaceStrong.withValues(alpha: 0.56),
        overlayColor: colors.accent.withValues(alpha: isDark ? 0.12 : 0.08),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13.6,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class SocialGlyph extends StatelessWidget {
  const SocialGlyph._({required this.child});

  factory SocialGlyph.google() {
    return const SocialGlyph._(
      child: Text(
        'G',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }

  factory SocialGlyph.apple() {
    return const SocialGlyph._(child: Icon(Icons.apple, size: 22));
  }

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class DarkTrustPanel extends StatelessWidget {
  const DarkTrustPanel({
    super.key,
    required this.secureTitle,
    required this.secureSubtitle,
    required this.fastTitle,
    required this.fastSubtitle,
    required this.lovedTitle,
    required this.lovedSubtitle,
  });

  final String secureTitle;
  final String secureSubtitle;
  final String fastTitle;
  final String fastSubtitle;
  final String lovedTitle;
  final String lovedSubtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceGlass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: FeatureColumn(
              icon: Icons.verified_user_outlined,
              iconColor: colors.accent,
              title: secureTitle,
              subtitle: secureSubtitle,
            ),
          ),
          FeatureDivider(color: colors.border),
          Expanded(
            child: FeatureColumn(
              icon: Icons.bolt_rounded,
              iconColor: colors.accent,
              title: fastTitle,
              subtitle: fastSubtitle,
            ),
          ),
          FeatureDivider(color: colors.border),
          Expanded(
            child: FeatureColumn(
              icon: Icons.favorite_border_rounded,
              iconColor: colors.accent,
              title: lovedTitle,
              subtitle: lovedSubtitle,
            ),
          ),
        ],
      ),
    );
  }
}

class LightPrivacyPanel extends StatelessWidget {
  const LightPrivacyPanel({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: isDark
            ? colors.accent.withValues(alpha: 0.08)
            : colors.accentSoft.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? colors.accent.withValues(alpha: 0.16)
              : colors.accent.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: isDark ? 0.16 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: isDark ? 0.12 : 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.shield_outlined, color: colors.accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 13.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.textSoft,
                    fontSize: 11.8,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FeatureColumn extends StatelessWidget {
  const FeatureColumn({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 26),
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textMuted, fontSize: 11, height: 1.35),
        ),
      ],
    );
  }
}

class FeatureDivider extends StatelessWidget {
  const FeatureDivider({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 82,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: color,
    );
  }
}

class ErrorCard extends StatelessWidget {
  const ErrorCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.danger.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 15,
              color: colors.danger.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  height: 1.28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BlurOrb extends StatelessWidget {
  const BlurOrb({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}
