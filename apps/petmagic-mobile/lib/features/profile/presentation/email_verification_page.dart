import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';

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

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage> {
  static const _resendCooldown = Duration(seconds: 60);

  final _codeController = TextEditingController();
  Timer? _resendCooldownTimer;
  bool _isBusy = false;
  int _resendSecondsRemaining = 0;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    if (widget.startResendCooldown) {
      _startResendCooldown();
    }
  }

  @override
  void dispose() {
    _resendCooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
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
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_info != null) Text(_info!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isBusy ? null : _verify,
              child: Text(
                _isBusy
                    ? text.emailVerificationWorkingLabel
                    : text.emailVerificationVerifyAction,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _isBusy || _resendSecondsRemaining > 0
                  ? null
                  : _resend,
              child: Text(_resendButtonLabel(text)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isBusy
                  ? null
                  : () => context.go(
                      '${AuthEntryPage.routePath}?email=${Uri.encodeQueryComponent(widget.email)}',
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
    setState(() {
      _isBusy = true;
      _error = null;
      _info = null;
    });

    try {
      final repository = ref.read(profileRepositoryProvider);
      final session = await repository.verifyEmailCode(
        email: widget.email,
        code: _codeController.text,
      );
      if (!mounted) return;

      ref
          .read(appLaunchControllerProvider.notifier)
          .markSignedInWithLegalStatus(
            requiresLegalAcceptance:
                session.user.legalAcceptance.requiresAcceptance,
          );
      setState(() {
        _info = text.emailVerificationConfirmedMessage;
      });
      context.go(TemplatesPage.routePath);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _mapVerificationError(error, text);
      });
    } finally {
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
    setState(() {
      _isBusy = true;
      _error = null;
      _info = null;
    });

    try {
      final repository = ref.read(profileRepositoryProvider);
      await repository.resendEmailVerificationCode(email: widget.email);
      if (!mounted) return;
      setState(() {
        _info = text.emailVerificationResentFallbackMessage;
      });
      _startResendCooldown();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _mapVerificationError(error, text);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  String _mapVerificationError(Object error, AppLocalizations text) {
    if (error is AppException) {
      return mapProfileFeedbackMessage(error.message, text);
    }
    return text.authRequestFailed;
  }

  void _startResendCooldown() {
    _resendCooldownTimer?.cancel();
    setState(() {
      _resendSecondsRemaining = _resendCooldown.inSeconds;
    });
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resendSecondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _resendSecondsRemaining = 0;
        });
        return;
      }

      setState(() {
        _resendSecondsRemaining--;
      });
    });
  }

  String _resendButtonLabel(AppLocalizations text) {
    if (_resendSecondsRemaining <= 0) {
      return text.emailVerificationResendAction;
    }

    return '${text.emailVerificationResendAction} (${_resendSecondsRemaining}s)';
  }
}
