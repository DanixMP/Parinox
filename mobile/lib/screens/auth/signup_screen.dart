import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import 'auth_look.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _userCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _obscure = true;
  String? _localError;

  @override
  void dispose() {
    _userCtrl.dispose();
    _nameCtrl.dispose();
    _passCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (email.isEmpty && phone.isEmpty) {
      setState(() => _localError = 'Add an email or phone number for account recovery.');
      return;
    }
    setState(() => _localError = null);
    await ref.read(authProvider.notifier).signup(
          username: _userCtrl.text.trim(),
          password: _passCtrl.text,
          displayName: _nameCtrl.text.trim(),
          email: email.isEmpty ? null : email,
          phone: phone.isEmpty ? null : phone,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final busy = auth.isLoading;
    final cs = AuthLook.scheme(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 24 + bottom),
            child: Column(
              children: [
                AuthCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Parinox',
                        textAlign: TextAlign.center,
                        style: AuthLook.brandLogo(context),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sign up to chat with your team.',
                        textAlign: TextAlign.center,
                        style: AuthLook.muted(context, size: 14).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _nameCtrl,
                        enabled: !busy,
                        textCapitalization: TextCapitalization.words,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface,
                            ),
                        decoration: AuthLook.fieldDecoration(
                          context,
                          hint: 'Display name',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _userCtrl,
                        enabled: !busy,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface,
                            ),
                        decoration: AuthLook.fieldDecoration(
                          context,
                          hint: 'Username',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passCtrl,
                        enabled: !busy,
                        obscureText: _obscure,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface,
                            ),
                        decoration: AuthLook.fieldDecoration(
                          context,
                          hint: 'Password',
                          suffix: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailCtrl,
                        enabled: !busy,
                        keyboardType: TextInputType.emailAddress,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface,
                            ),
                        decoration: AuthLook.fieldDecoration(
                          context,
                          hint: 'Email',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneCtrl,
                        enabled: !busy,
                        keyboardType: TextInputType.phone,
                        onSubmitted: (_) => busy ? null : _submit(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface,
                            ),
                        decoration: AuthLook.fieldDecoration(
                          context,
                          hint: 'Phone (optional if email set)',
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        style: AuthLook.primaryButton(context),
                        onPressed: busy ? null : _submit,
                        child: busy
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cs.onPrimary,
                                ),
                              )
                            : const Text('Sign up'),
                      ),
                      if (_localError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _localError!,
                          textAlign: TextAlign.center,
                          style: AuthLook.muted(context).copyWith(color: cs.error),
                        ),
                      ],
                      if (auth.valueOrNull?.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          auth.valueOrNull!.errorMessage!,
                          textAlign: TextAlign.center,
                          style: AuthLook.muted(context).copyWith(color: cs.error),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AuthCard(
                  padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 24),
                  child: Text.rich(
                    TextSpan(
                      style: AuthLook.muted(context, size: 14).copyWith(
                        color: cs.onSurface,
                      ),
                      children: [
                        const TextSpan(text: 'Have an account? '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: busy ? null : () => Navigator.of(context).maybePop(),
                            child: Text(
                              'Log in',
                              style: AuthLook.link(context, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
