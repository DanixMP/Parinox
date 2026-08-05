import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import 'auth_look.dart';
import 'signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref.read(authProvider.notifier).login(
          _userCtrl.text.trim(),
          _passCtrl.text,
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
              mainAxisAlignment: MainAxisAlignment.center,
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
                      const SizedBox(height: 28),
                      TextField(
                        controller: _userCtrl,
                        enabled: !busy,
                        textInputAction: TextInputAction.next,
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
                        onSubmitted: (_) => busy ? null : _submit(),
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
                            : const Text('Log in'),
                      ),
                      const SizedBox(height: 18),
                      const AuthOrDivider(),
                      const SizedBox(height: 18),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                _userCtrl.text = 'alice';
                                _passCtrl.text = 'securepass';
                                await _submit();
                              },
                        style: TextButton.styleFrom(
                          foregroundColor: cs.primary,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 18, color: cs.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Continue as guest demo',
                              style: AuthLook.link(context, size: 14),
                            ),
                          ],
                        ),
                      ),
                      if (auth.valueOrNull?.errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          auth.valueOrNull!.errorMessage!,
                          textAlign: TextAlign.center,
                          style: AuthLook.muted(context, size: 12).copyWith(
                            color: cs.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: null,
                        child: Text(
                          'Forgot password?',
                          style: AuthLook.muted(context, size: 12).copyWith(
                            color: cs.onSurface,
                          ),
                        ),
                      ),
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
                        const TextSpan(text: "Don't have an account? "),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: busy
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const SignupScreen(),
                                      ),
                                    );
                                  },
                            child: Text(
                              'Sign up',
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
