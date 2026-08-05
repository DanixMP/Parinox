import 'package:cupertino_onboarding/cupertino_onboarding.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';

const _onboardingKey = 'parinox_onboarding_done_v3';

/// Shows onboarding once, then login for unauthenticated users.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _done;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _done = prefs.getBool(_onboardingKey) ?? false);
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    if (!mounted) return;
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_done == null) {
      return Scaffold(
        backgroundColor: cs.surfaceContainerLow,
        body: Center(child: CircularProgressIndicator(color: cs.primary)),
      );
    }
    if (_done == true) return const LoginScreen();
    return OnboardingScreen(onFinished: _finish);
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = cs.primary;

    return CupertinoTheme(
      data: CupertinoThemeData(
        brightness: Theme.of(context).brightness,
        primaryColor: accent,
        scaffoldBackgroundColor: cs.surfaceContainerLow,
        barBackgroundColor: cs.surfaceContainerLow,
        textTheme: CupertinoTextThemeData(
          primaryColor: accent,
          textStyle: TextStyle(color: cs.onSurface),
          navTitleTextStyle: TextStyle(
            color: cs.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          navLargeTitleTextStyle: TextStyle(
            color: cs.onSurface,
            fontSize: 34,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: Material(
        color: cs.surfaceContainerLow,
        child: CupertinoOnboarding(
          backgroundColor: cs.surfaceContainerLow,
          bottomButtonColor: cs.primary,
          bottomButtonBorderRadius: BorderRadius.circular(14),
          bottomButtonChild: Text(
            'Continue',
            style: TextStyle(
              color: cs.onPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),
          onPressedOnLastPage: onFinished,
          pages: [
            WhatsNewPage(
              title: Text(
                "What's New in Parinox",
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              features: [
                WhatsNewFeature(
                  icon: Icon(CupertinoIcons.chat_bubble_2_fill, color: accent),
                  title: Text('Private team chat', style: TextStyle(color: cs.onSurface)),
                  description: Text(
                    'Channels, groups, and DMs built for real-time conversation.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
                WhatsNewFeature(
                  icon: Icon(CupertinoIcons.paintbrush_fill, color: accent),
                  title: Text('Themes that fit you', style: TextStyle(color: cs.onSurface)),
                  description: Text(
                    'Swap design systems and chat looks without leaving the app.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
                WhatsNewFeature(
                  icon: Icon(CupertinoIcons.music_note_2, color: accent),
                  title: Text('Music in the moment', style: TextStyle(color: cs.onSurface)),
                  description: Text(
                    'Share tracks and keep listening with the in-app library.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            CupertinoOnboardingPage(
              title: Text(
                'Stay close to your team',
                style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700),
              ),
              body: Icon(
                CupertinoIcons.person_3_fill,
                size: 160,
                color: accent,
              ),
            ),
            CupertinoOnboardingPage(
              title: Text(
                'Calls, stories, and more',
                style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700),
              ),
              body: Icon(
                CupertinoIcons.phone_fill,
                size: 160,
                color: accent,
              ),
            ),
            CupertinoOnboardingPage(
              title: Text(
                'Ready when you are',
                style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700),
              ),
              body: Icon(
                CupertinoIcons.check_mark_circled_solid,
                size: 160,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
