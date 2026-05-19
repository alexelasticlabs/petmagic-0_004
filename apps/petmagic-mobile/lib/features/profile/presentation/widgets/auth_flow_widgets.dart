import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';

class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: -40,
            top: 72,
            child: BlurOrb(
              size: 140,
              color: colors.accent.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            right: -50,
            top: 118,
            child: BlurOrb(
              size: 170,
              color: colors.gold.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            right: 24,
            top: 92,
            child: Icon(
              Icons.pets_rounded,
              size: 26,
              color: colors.accent.withValues(alpha: 0.35),
            ),
          ),
          Positioned(
            left: 38,
            top: 124,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: colors.gold.withValues(alpha: 0.45),
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
  });

  final String title;
  final String subtitle;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AuthWordmark(isDark: isDark),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    color: colors.textStrong,
                    fontSize: isDark ? 30 : 27,
                    height: 1.02,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.9,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: GoogleFonts.nunito(
                    color: colors.textSoft,
                    fontSize: 14,
                    height: 1.38,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: isDark ? 230 : 210,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          colors.gold.withValues(alpha: 0.16),
                          colors.accent.withValues(alpha: 0.28),
                          colors.accent.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                        stops: const [0.08, 0.4, 0.75, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 18,
                  top: 28,
                  bottom: 20,
                  child: Transform.rotate(
                    angle: -0.14,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors.surfaceGlass.withValues(
                              alpha: isDark ? 0.3 : 0.88,
                            ),
                            colors.surface.withValues(
                              alpha: isDark ? 0.14 : 0.55,
                            ),
                          ],
                        ),
                        border: Border.all(
                          color: colors.border.withValues(
                            alpha: isDark ? 0.7 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -22,
                  right: -22,
                  top: -6,
                  bottom: -18,
                  child: Transform.scale(
                    scale: 1.4,
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
    );
  }
}

class AuthWordmark extends StatelessWidget {
  const AuthWordmark({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.accentSoft, colors.gold.withValues(alpha: 0.28)],
            ),
            boxShadow: [
              BoxShadow(
                color: colors.accent.withValues(alpha: isDark ? 0.2 : 0.12),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(Icons.pets_rounded, color: colors.accent, size: 34),
        ),
        const SizedBox(height: 10),
        Text(
          'PetMagic',
          style: GoogleFonts.comfortaa(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: isDark ? colors.textStrong : const Color(0xFF10234A),
          ),
        ),
      ],
    );
  }
}

class AuthFormCard extends StatelessWidget {
  const AuthFormCard({super.key, required this.child, required this.isDark});

  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: isDark ? 14 : 10,
          sigmaY: isDark ? 14 : 10,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.surfaceGlass.withValues(alpha: isDark ? 0.95 : 0.98),
                colors.surface.withValues(alpha: isDark ? 0.84 : 0.92),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 24,
                offset: const Offset(0, 14),
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
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final ValueChanged<String> onChanged;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      style: TextStyle(
        color: colors.textStrong,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: colors.textMuted,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(prefixIcon, color: colors.textSoft),
        suffixIcon: trailing,
        filled: true,
        fillColor: colors.surface.withValues(alpha: 0.98),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colors.border.withValues(alpha: 0.75)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: colors.accent.withValues(alpha: 0.75),
            width: 1.4,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
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
        Expanded(child: Divider(color: colors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: colors.border)),
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
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        foregroundColor: colors.textStrong,
        backgroundColor: colors.surfaceGlass,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.accentSoft.withValues(alpha: 0.9), colors.surface],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: colors.accent, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.textSoft,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, color: colors.accent, size: 14),
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
        color: colors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.danger.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          message,
          style: TextStyle(
            color: colors.textStrong,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
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
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
