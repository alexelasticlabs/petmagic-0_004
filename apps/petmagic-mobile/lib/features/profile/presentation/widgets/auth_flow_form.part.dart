part of 'auth_flow_widgets.dart';

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
    final colors = context.petMagicColors;
    final content = Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceGlass.withValues(alpha: 0.72)
            : colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.border.withValues(alpha: isDark ? 0.44 : 0.58),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? colors.shadow.withValues(alpha: 0.35)
                : colors.shadow.withValues(alpha: 0.18),
            blurRadius: compact ? 24 : 32,
            offset: Offset(0, compact ? 8 : 12),
          ),
        ],
      ),
      child: child,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: PerformanceGuard.shouldAvoidBlur(context)
          ? content
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: content,
            ),
    );
  }
}

class AuthField extends StatefulWidget {
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
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final labelStyle = Theme.of(context).textTheme.bodyMedium;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final isFocused = _focusNode.hasFocus;
    final duration = PetMotion.effectiveDuration(context, PetMotion.fast);
    final inputFill = widget.enabled
        ? (isDark ? colors.surfaceStrong : colors.surface)
        : colors.surfaceStrong.withValues(alpha: isDark ? 0.62 : 0.5);
    final iconColor = widget.enabled
        ? (isFocused ? colors.accent : colors.textSoft)
        : colors.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: duration,
          curve: PetMotion.emphasized,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              if (isFocused || hasError)
                BoxShadow(
                  color: (hasError ? colors.danger : colors.accent).withValues(
                    alpha: isDark ? 0.2 : 0.16,
                  ),
                  blurRadius: hasError ? 14 : 18,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Semantics(
            label: widget.hintText,
            child: TextField(
              focusNode: _focusNode,
              controller: widget.controller,
              onChanged: widget.onChanged,
              enabled: widget.enabled,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              obscureText: widget.obscureText,
              style: labelStyle?.copyWith(
                color: widget.enabled ? colors.textStrong : colors.textMuted,
                fontSize: widget.compact ? 13 : 14,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                constraints: BoxConstraints(
                  minHeight: widget.compact ? 50 : 54,
                ),
                hint: ExcludeSemantics(
                  child: Text(
                    widget.hintText,
                    style: labelStyle?.copyWith(
                      color: colors.textMuted.withValues(
                        alpha: isDark ? 0.82 : 0.72,
                      ),
                      fontSize: widget.compact ? 12.5 : 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                prefixIcon: AnimatedSwitcher(
                  duration: duration,
                  child: Padding(
                    key: ValueKey(iconColor),
                    padding: const EdgeInsets.only(left: 14, right: 6),
                    child: Icon(widget.prefixIcon, color: iconColor, size: 20),
                  ),
                ),
                prefixIconConstraints: BoxConstraints(
                  minWidth: 44,
                  minHeight: widget.compact ? 50 : 54,
                ),
                suffixIcon: widget.trailing,
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
                    color: colors.border.withValues(
                      alpha: isDark ? 0.64 : 0.72,
                    ),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: hasError ? colors.danger : colors.accent,
                    width: 1.55,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: colors.border.withValues(
                      alpha: isDark ? 0.38 : 0.45,
                    ),
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
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: widget.compact ? 13 : 15,
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: duration,
          curve: PetMotion.emphasized,
          alignment: Alignment.topLeft,
          child: AnimatedSwitcher(
            duration: duration,
            child: hasError
                ? Padding(
                    key: ValueKey(widget.errorText),
                    padding: const EdgeInsets.only(left: 6, top: 6),
                    child: Text(
                      widget.errorText!,
                      style: TextStyle(
                        color: colors.danger.withValues(
                          alpha: isDark ? 0.92 : 0.86,
                        ),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('no-error')),
          ),
        ),
      ],
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
              fontSize: 11.5,
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
            ? colors.surfaceGlass.withValues(alpha: 0.86)
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
              fontSize: 14,
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
