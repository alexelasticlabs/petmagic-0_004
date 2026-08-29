import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/shared/widgets/motion.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_animated_button_child.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_animated_value_text.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_async_state_view.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_image_state.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_interactive_surface.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_unavailable_view.dart';

void main() {
  testWidgets('PetMagicAnimatedButtonChild animates loading content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const FilledButton(
          onPressed: null,
          child: PetMagicAnimatedButtonChild(
            label: 'Continue',
            loadingLabel: 'Loading',
            isLoading: true,
          ),
        ),
      ),
    );

    expect(find.text('Loading'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('PetMagicAsyncStateView exposes retry action', (tester) async {
    var retryCount = 0;

    await tester.pumpWidget(
      _host(
        PetMagicAsyncStateView(
          icon: Icons.cloud_off_rounded,
          title: 'Offline',
          message: 'Try again later.',
          actionLabel: 'Retry',
          onAction: () => retryCount++,
        ),
      ),
    );

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(retryCount, 1);
  });

  testWidgets('PetMagicUnavailableView renders offline copy', (tester) async {
    await tester.pumpWidget(
      _host(
        const PetMagicUnavailableView(
          kind: AppUnavailableKind.offline,
          onRetry: _noop,
        ),
      ),
    );

    expect(find.text("You're offline"), findsOneWidget);
    expect(find.textContaining("We'll retry automatically"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('PetMagicUnavailableView renders server copy', (tester) async {
    await tester.pumpWidget(
      _host(
        const PetMagicUnavailableView(
          kind: AppUnavailableKind.serverUnavailable,
          onRetry: _noop,
        ),
      ),
    );

    expect(find.text('Server is unavailable'), findsOneWidget);
    expect(
      find.textContaining('PetMagic is temporarily unavailable'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('PetMagicImageState shows fallback retry state', (tester) async {
    var retryCount = 0;

    await tester.pumpWidget(
      _host(
        PetMagicImageState(
          errorTitle: 'Preview failed',
          retryLabel: 'Retry',
          onRetry: () => retryCount++,
          child: const Text('image'),
        ),
      ),
    );

    expect(find.text('Preview failed'), findsOneWidget);
    expect(find.text('image'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(retryCount, 1);
  });

  testWidgets('PetMagicInteractiveSurface respects disabled state', (
    tester,
  ) async {
    var tapCount = 0;

    await tester.pumpWidget(
      _host(
        PetMagicInteractiveSurface(
          enabled: false,
          onTap: () => tapCount++,
          child: const SizedBox(width: 80, height: 44, child: Text('Tap')),
        ),
      ),
    );

    await tester.tap(find.text('Tap'));
    await tester.pump();

    expect(tapCount, 0);
  });

  testWidgets('PetMotion shortens durations when animations are disabled', (
    tester,
  ) async {
    late Duration duration;

    await tester.pumpWidget(
      _host(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              duration = PetMotion.effectiveDuration(context, PetMotion.medium);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(duration, lessThan(PetMotion.medium));
    expect(duration.inMilliseconds, greaterThanOrEqualTo(60));
  });

  testWidgets('animated value transitions only between confirmed values', (
    tester,
  ) async {
    await tester.pumpWidget(_animatedValueHost('120'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_animatedValueHost('95'));

    expect(find.text('120'), findsOneWidget);
    expect(find.text('95'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('animated-value')),
        matching: find.byType(AnimatedSwitcher),
      ),
      findsOneWidget,
    );

    await tester.pumpAndSettle();
    expect(find.text('120'), findsNothing);
    expect(find.text('95'), findsOneWidget);
  });

  testWidgets('animated value snaps in reduced and degraded motion modes', (
    tester,
  ) async {
    for (final mediaQueryData in const [
      MediaQueryData(
        size: Size(500, 900),
        devicePixelRatio: 2,
        disableAnimations: true,
      ),
      MediaQueryData(size: Size(390, 844), devicePixelRatio: 3),
    ]) {
      await tester.pumpWidget(
        _animatedValueHost('120', mediaQueryData: mediaQueryData),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _animatedValueHost('95', mediaQueryData: mediaQueryData),
      );

      expect(find.text('120'), findsNothing);
      expect(find.text('95'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('animated-value')),
          matching: find.byType(AnimatedSwitcher),
        ),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

Widget _animatedValueHost(
  String value, {
  MediaQueryData mediaQueryData = const MediaQueryData(
    size: Size(500, 900),
    devicePixelRatio: 2,
  ),
}) {
  return _host(
    MediaQuery(
      data: mediaQueryData,
      child: PetMagicAnimatedValueText(
        key: const Key('animated-value'),
        value: value,
      ),
    ),
  );
}

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

void _noop() {}
