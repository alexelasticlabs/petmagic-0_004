import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';

part 'magic_loading_background_painter.part.dart';
part 'magic_loading_foreground.part.dart';

class MagicLoadingScreen extends StatefulWidget {
  const MagicLoadingScreen({
    super.key,
    this.messages,
    this.title,
    this.showBackground = true,
  });

  final List<String>? messages;
  final String? title;
  final bool showBackground;

  @override
  State<MagicLoadingScreen> createState() => _MagicLoadingScreenState();
}

class _MagicLoadingScreenState extends State<MagicLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _messageTimer;
  int _messageIndex = 0;
  bool _usesStaticDecorations = false;
  bool _animatesLoadingSignal = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimationMode();
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final messages = _resolveMessages(text);
    final message = messages[_messageIndex % messages.length];
    final title = widget.title?.trim();
    final useStaticDecorations = _usesStaticDecorations;
    final animateLoadingSignal = _animatesLoadingSignal;

    final child = Semantics(
      container: true,
      liveRegion: true,
      label: title == null || title.isEmpty ? message : '$title. $message',
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: useStaticDecorations
                ? CustomPaint(
                    painter: _MagicBackgroundPainter(
                      colors: colors,
                      progress: 0.22,
                    ),
                  )
                : AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _MagicBackgroundPainter(
                          colors: colors,
                          progress: _controller.value,
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MagicPortal(controller: _controller),
                      const SizedBox(height: 30),
                      if (title != null && title.isNotEmpty) ...[
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (!animateLoadingSignal)
                        Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.textSoft,
                            fontSize: 16,
                            height: 1.28,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: Text(
                            message,
                            key: ValueKey(message),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textSoft,
                              fontSize: 16,
                              height: 1.28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      _PawProgress(controller: _controller),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (!widget.showBackground) {
      return child;
    }

    return DecoratedBox(
      key: const ValueKey('magic-loading-screen'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.backgroundTop,
            Color.alphaBlend(
              colors.accent.withValues(alpha: 0.13),
              colors.backgroundBottom,
            ),
            Color.alphaBlend(
              colors.purple.withValues(alpha: 0.12),
              colors.backgroundBottom,
            ),
            colors.backgroundBottom,
          ],
          stops: const [0, 0.38, 0.74, 1],
        ),
      ),
      child: child,
    );
  }

  List<String> _resolveMessages(AppLocalizations text) {
    final provided = widget.messages
        ?.map((message) => message.trim())
        .where((message) => message.isNotEmpty)
        .toList(growable: false);

    if (provided != null && provided.isNotEmpty) {
      return provided;
    }

    return [
      text.magicLoadingPreparing,
      text.magicLoadingCutestAngle,
      text.magicLoadingAiPaws,
      text.magicLoadingCreatingAdorable,
      text.magicLoadingAlmostReady,
    ];
  }

  void _syncAnimationMode() {
    final nextUsesStaticDecorations =
        !PerformanceGuard.shouldAnimateRepeatingEffects(context);
    final nextAnimatesLoadingSignal =
        PerformanceGuard.shouldAnimateLoadingIndicators(context);
    _usesStaticDecorations = nextUsesStaticDecorations;
    _animatesLoadingSignal = nextAnimatesLoadingSignal;

    if (!nextAnimatesLoadingSignal) {
      _messageTimer?.cancel();
      _messageTimer = null;
      _messageIndex = 0;
      _controller
        ..stop()
        ..value = 0.22;
      return;
    }

    if (!_controller.isAnimating) {
      _controller.repeat();
    }
    if (_messageTimer == null) {
      _scheduleNextMessageTick();
    }
  }

  void _scheduleNextMessageTick() {
    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(milliseconds: 1700), () {
      if (!mounted || !_animatesLoadingSignal) {
        return;
      }

      setState(() => _messageIndex++);
      _scheduleNextMessageTick();
    });
  }
}

class SliverMagicLoadingScreen extends StatelessWidget {
  const SliverMagicLoadingScreen({
    super.key,
    this.messages,
    this.title,
    this.showBackground = false,
  });

  final List<String>? messages;
  final String? title;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: MagicLoadingScreen(
        messages: messages,
        title: title,
        showBackground: showBackground,
      ),
    );
  }
}
