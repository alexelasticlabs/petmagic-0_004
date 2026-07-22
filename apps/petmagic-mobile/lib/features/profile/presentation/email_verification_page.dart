import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/features/profile/application/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  const EmailVerificationPage({
    super.key,
    required this.email,
    this.startResendCooldown = false,
  });

  static const routePath = '/verify-email';

  final String email;
  final bool startResendCooldown;

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class EmailVerificationRouteArgs {
  const EmailVerificationRouteArgs({
    required this.email,
    this.startResendCooldown = false,
  });

  final String email;
  final bool startResendCooldown;
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage>
    with WidgetsBindingObserver {
  static const _resendCooldown = Duration(seconds: 60);

  final _codeController = TextEditingController();
  Timer? _resendCooldownTimer;
  RequestCancellation? _activeRequestCancelToken;
  DateTime? _resendCooldownEndsAtUtc;
  bool _isBusy = false;
  int _resendSecondsRemaining = 0;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.startResendCooldown) {
      _startResendCooldown();
    }
  }

  @override
  void dispose() {
    _resendCooldownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _cancelActiveRequest();
    _codeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncResendCooldownAfterResume();
      return;
    }

    _resendCooldownTimer?.cancel();
    _resendCooldownTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final hasInternet = ref.watch(
      networkStatusControllerProvider.select((status) => status.hasInternet),
    );
    final offlineMessage = mapProfileFeedbackMessage(
      'templates.network_unavailable',
      text,
    );

    ref.listen<NetworkStatusState>(networkStatusControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.hasInternet == next.hasInternet || !mounted) {
        return;
      }

      if (!next.hasInternet) {
        _cancelActiveRequest();
        setState(() {
          _isBusy = false;
          _error = null;
          _info = null;
        });
        return;
      }

      if (normalizeProfileFeedbackKey(_error) !=
          'templates.network_unavailable') {
        return;
      }

      setState(() {
        _error = null;
      });
    });

    return Scaffold(
      appBar: AppBar(title: Text(text.emailVerificationTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(text.emailVerificationCodeSentMessage(widget.email)),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: text.emailVerificationCodeLabel,
              ),
            ),
            if (!hasInternet)
              Text(offlineMessage, style: TextStyle(color: colors.error)),
            if (_error != null)
              Text(_error!, style: TextStyle(color: colors.error)),
            if (_info != null) Text(_info!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isBusy || !hasInternet ? null : _verify,
              child: Text(
                _isBusy
                    ? text.emailVerificationWorkingLabel
                    : text.emailVerificationVerifyAction,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _isBusy || _resendSecondsRemaining > 0 || !hasInternet
                  ? null
                  : _resend,
              child: Text(_resendButtonLabel(text)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isBusy
                  ? null
                  : () => context.appNavigator.go(
                      AuthDestination(
                        payload: AuthEntryRouteArgs(initialEmail: widget.email),
                      ),
                    ),
              child: Text(text.emailVerificationChangeEmailAction),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verify() async {
    if (_isBusy) {
      return;
    }

    final text = AppLocalizations.of(context);
    if (!ref.read(networkStatusControllerProvider).hasInternet) {
      setState(() {
        _error = mapProfileFeedbackMessage(
          'templates.network_unavailable',
          text,
        );
        _info = null;
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
      _info = null;
    });

    final cancelToken = _startRequestCancelToken();
    try {
      final repository = ref.read(profileRepositoryProvider);
      final session = await repository.verifyEmailCode(
        email: widget.email,
        code: _codeController.text,
        cancelToken: cancelToken,
      );
      if (!mounted || cancelToken.isCancelled) return;

      ref
          .read(appLaunchControllerProvider.notifier)
          .markSignedInWithLegalStatus(
            requiresLegalAcceptance:
                session.user.legalAcceptance.requiresAcceptance,
          );
      setState(() {
        _info = text.emailVerificationConfirmedMessage;
      });
      context.appNavigator.go(const TemplatesDestination());
    } catch (error) {
      if (error is RequestCancelledException) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = _mapVerificationError(error, text);
      });
    } finally {
      _clearActiveRequest(cancelToken);
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _resend() async {
    if (_isBusy) {
      return;
    }

    final text = AppLocalizations.of(context);
    if (!ref.read(networkStatusControllerProvider).hasInternet) {
      setState(() {
        _error = mapProfileFeedbackMessage(
          'templates.network_unavailable',
          text,
        );
        _info = null;
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
      _info = null;
    });

    final cancelToken = _startRequestCancelToken();
    try {
      final repository = ref.read(profileRepositoryProvider);
      await repository.resendEmailVerificationCode(
        email: widget.email,
        cancelToken: cancelToken,
      );
      if (!mounted || cancelToken.isCancelled) return;
      setState(() {
        _info = text.emailVerificationResentFallbackMessage;
      });
      _startResendCooldown();
    } catch (error) {
      if (error is RequestCancelledException) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = _mapVerificationError(error, text);
      });
    } finally {
      _clearActiveRequest(cancelToken);
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  RequestCancellation _startRequestCancelToken() {
    _cancelActiveRequest();
    final cancelToken = RequestCancellation();
    _activeRequestCancelToken = cancelToken;
    return cancelToken;
  }

  void _cancelActiveRequest() {
    final cancelToken = _activeRequestCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('email_verification_cancelled');
    }
    _activeRequestCancelToken = null;
  }

  void _clearActiveRequest(RequestCancellation cancelToken) {
    if (identical(_activeRequestCancelToken, cancelToken)) {
      _activeRequestCancelToken = null;
    }
  }

  String _mapVerificationError(Object error, AppLocalizations text) {
    if (error is AppException) {
      return mapProfileFeedbackMessage(error.message, text);
    }
    return text.authRequestFailed;
  }

  void _startResendCooldown() {
    _resendCooldownEndsAtUtc = DateTime.now().toUtc().add(_resendCooldown);
    _resendCooldownTimer?.cancel();
    setState(() {
      _resendSecondsRemaining = _resendCooldown.inSeconds;
    });
    _scheduleResendCooldownTick();
  }

  void _scheduleResendCooldownTick() {
    _resendCooldownTimer?.cancel();
    _resendCooldownTimer = null;
    if (_resendSecondsRemaining <= 0) {
      return;
    }
    _resendCooldownTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) {
        return;
      }

      if (_resendSecondsRemaining <= 1) {
        _resendCooldownEndsAtUtc = null;
        setState(() {
          _resendSecondsRemaining = 0;
        });
        return;
      }

      setState(() {
        _resendSecondsRemaining--;
      });
      _scheduleResendCooldownTick();
    });
  }

  void _syncResendCooldownAfterResume() {
    final secondsRemaining = _remainingResendCooldownSeconds();
    if (!mounted) {
      return;
    }

    if (secondsRemaining <= 0) {
      _resendCooldownEndsAtUtc = null;
      _resendCooldownTimer?.cancel();
      _resendCooldownTimer = null;
      if (_resendSecondsRemaining != 0) {
        setState(() {
          _resendSecondsRemaining = 0;
        });
      }
      return;
    }

    if (_resendSecondsRemaining != secondsRemaining) {
      setState(() {
        _resendSecondsRemaining = secondsRemaining;
      });
    }
    _scheduleResendCooldownTick();
  }

  int _remainingResendCooldownSeconds() {
    final endsAt = _resendCooldownEndsAtUtc;
    if (endsAt == null) {
      return 0;
    }

    final millisecondsRemaining = endsAt
        .difference(DateTime.now().toUtc())
        .inMilliseconds;
    if (millisecondsRemaining <= 0) {
      return 0;
    }

    return (millisecondsRemaining + 999) ~/ 1000;
  }

  String _resendButtonLabel(AppLocalizations text) {
    if (_resendSecondsRemaining <= 0) {
      return text.emailVerificationResendAction;
    }

    return '${text.emailVerificationResendAction} (${_resendSecondsRemaining}s)';
  }
}
