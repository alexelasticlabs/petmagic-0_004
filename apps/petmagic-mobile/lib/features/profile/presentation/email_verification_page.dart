import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  const EmailVerificationPage({
    super.key,
    required this.email,
    this.initialPassword,
  });

  static const routePath = '/verify-email';

  final String email;
  final String? initialPassword;

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage> {
  final _codeController = TextEditingController();
  bool _isBusy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
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
              onPressed: _isBusy ? null : _resend,
              child: Text(text.emailVerificationResendAction),
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
    final text = AppLocalizations.of(context);
    setState(() {
      _isBusy = true;
      _error = null;
      _info = null;
    });

    try {
      final repository = ref.read(profileRepositoryProvider);
      await repository.verifyEmailCode(
        email: widget.email,
        code: _codeController.text,
      );
      if (!mounted) return;

      final password = widget.initialPassword;
      if (password != null && password.isNotEmpty) {
        final session = await repository.login(
          email: widget.email,
          password: password,
        );
        if (!mounted) return;
        ref
            .read(appLaunchControllerProvider.notifier)
            .markSignedInWithLegalStatus(
              requiresLegalAcceptance:
                  session.user.legalAcceptance.requiresAcceptance,
            );
        context.go(TemplatesPage.routePath);
        return;
      }

      setState(() {
        _info = text.emailVerificationConfirmedMessage;
      });
      context.go(
        '${AuthEntryPage.routePath}?email=${Uri.encodeQueryComponent(widget.email)}',
      );
    } catch (error) {
      setState(() {
        _error = error.toString();
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
    final text = AppLocalizations.of(context);
    setState(() {
      _isBusy = true;
      _error = null;
      _info = null;
    });

    try {
      final repository = ref.read(profileRepositoryProvider);
      await repository.resendEmailVerificationCode(email: widget.email);
      setState(() {
        _info = text.emailVerificationResentFallbackMessage;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }
}
