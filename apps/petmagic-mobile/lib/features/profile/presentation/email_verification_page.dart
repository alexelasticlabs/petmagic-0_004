import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  const EmailVerificationPage({super.key, required this.email});

  static const routePath = '/verify-email';

  final String email;

  @override
  ConsumerState<EmailVerificationPage> createState() => _EmailVerificationPageState();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Verify email')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('We sent a 6-digit code to ${widget.email}.'),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Code'),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_info != null) Text(_info!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isBusy ? null : _verify,
              child: Text(_isBusy ? 'Working...' : 'Verify'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _isBusy ? null : _resend,
              child: const Text('Send code again'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isBusy
                  ? null
                  : () => context.go('${AuthEntryPage.routePath}?email=${Uri.encodeQueryComponent(widget.email)}'),
              child: const Text('Change email'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verify() async {
    setState(() {
      _isBusy = true;
      _error = null;
      _info = null;
    });

    try {
      final repository = ref.read(profileRepositoryProvider);
      await repository.verifyEmailCode(email: widget.email, code: _codeController.text);
      if (!mounted) return;
      setState(() {
        _info = 'Email confirmed. Please sign in.';
      });
      context.go('${AuthEntryPage.routePath}?email=${Uri.encodeQueryComponent(widget.email)}');
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
    setState(() {
      _isBusy = true;
      _error = null;
      _info = null;
    });

    try {
      final repository = ref.read(profileRepositoryProvider);
      await repository.resendEmailVerificationCode(email: widget.email);
      setState(() {
        _info = 'If the account exists, a new code has been sent.';
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
