import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/island_back_button.dart';
import '../settings/ios_settings_chrome.dart';

const _secretUnlockedKey = 'parinox_secret_garden_v1';

/// About Parinox — tap the app name 10+ times to unlock a secret setting.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  int _taps = 0;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _loadUnlock();
  }

  Future<void> _loadUnlock() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _unlocked = prefs.getBool(_secretUnlockedKey) ?? false);
  }

  Future<void> _onAboutTap() async {
    if (_unlocked) return;
    setState(() => _taps += 1);
    if (_taps < 10) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_secretUnlockedKey, true);
    if (!mounted) return;
    setState(() => _unlocked = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Something bloomed…')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return IosSettingsScaffold(
      title: 'About',
      children: [
        IosSettingsGroup(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _onAboutTap,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: cs.shadow.withValues(alpha: 0.12),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.bolt_rounded,
                            size: 44,
                            color: cs.onPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Parinox',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Version 0.1.0',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Private team messaging — chats, channels, groups, calls, stories, and Explore, built for people who work and stay close.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.45,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const IosSettingsSectionLabel('Details'),
        IosSettingsGroup(
          children: [
            IosSettingsTile(
              icon: Icons.info_outline_rounded,
              iconBackground: IosSettingsAccents.blue,
              title: 'About the app',
              value: '0.1.0',
              onTap: _onAboutTap,
            ),
            IosSettingsTile(
              icon: Icons.code_rounded,
              iconBackground: IosSettingsAccents.gray,
              title: 'Open-source licenses',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Parinox',
                applicationVersion: '0.1.0',
                applicationLegalese: 'Private team messaging',
              ),
            ),
          ],
        ),
        const IosSettingsFooter(
          'Parinox keeps your conversations private and real-time. Tap About thoughtfully.',
        ),
        if (_unlocked) ...[
          const SizedBox(height: 8),
          const IosSettingsSectionLabel('Hidden'),
          IosSettingsGroup(
            children: [
              IosSettingsTile(
                icon: Icons.local_florist_rounded,
                iconBackground: IosSettingsAccents.pink,
                title: 'Secret garden',
                value: 'Draw a rose',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RoseDrawingScreen()),
                  );
                },
              ),
            ],
          ),
          const IosSettingsFooter(
            'You found it. Enjoy the bloom.',
          ),
        ],
      ],
    );
  }
}

/// Full-screen animated rose stroke drawing.
class RoseDrawingScreen extends StatefulWidget {
  const RoseDrawingScreen({super.key});

  @override
  State<RoseDrawingScreen> createState() => _RoseDrawingScreenState();
}

class _RoseDrawingScreenState extends State<RoseDrawingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      body: IslandBackOverlay(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 48),
              Text(
                'A rose for you',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Watch it bloom',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _RosePainter(
                        progress: Curves.easeInOutCubic.transform(_ctrl.value),
                        stroke: cs.error,
                        stem: cs.tertiary,
                        fill: cs.error.withValues(alpha: 0.12),
                      ),
                      child: const SizedBox.expand(),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: TextButton(
                  onPressed: () {
                    _ctrl
                      ..reset()
                      ..forward();
                  },
                  child: const Text('Draw again'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RosePainter extends CustomPainter {
  _RosePainter({
    required this.progress,
    required this.stroke,
    required this.stem,
    required this.fill,
  });

  final double progress;
  final Color stroke;
  final Color stem;
  final Color fill;

  Path _rosePath(Size size) {
    final c = Offset(size.width / 2, size.height * 0.42);
    final scale = math.min(size.width, size.height) * 0.16;
    final path = Path();
    // Rhodonea rose: r = a * cos(kθ) with k=5 → five petals, plus a soft offset bloom.
    var first = true;
    for (var i = 0; i <= 360; i++) {
      final t = i / 360 * math.pi * 2;
      final r = scale * (0.55 + 0.45 * math.cos(5 * t));
      final x = c.dx + r * math.cos(t);
      final y = c.dy + r * math.sin(t) * 0.92;
      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Inner swirl for a drawn feel.
    final swirl = Path();
    first = true;
    for (var i = 0; i <= 220; i++) {
      final t = i / 220 * math.pi * 4.2;
      final r = scale * (0.08 + 0.22 * (i / 220));
      final x = c.dx + r * math.cos(t);
      final y = c.dy + r * math.sin(t) * 0.9;
      if (first) {
        swirl.moveTo(x, y);
        first = false;
      } else {
        swirl.lineTo(x, y);
      }
    }
    path.addPath(swirl, Offset.zero);
    return path;
  }

  Path _stemPath(Size size) {
    final c = Offset(size.width / 2, size.height * 0.42);
    final bottom = Offset(size.width / 2, size.height * 0.82);
    final path = Path()
      ..moveTo(c.dx, c.dy + math.min(size.width, size.height) * 0.12)
      ..cubicTo(
        c.dx - 18,
        c.dy + 60,
        bottom.dx + 22,
        bottom.dy - 40,
        bottom.dx,
        bottom.dy,
      );
    // Leaf.
    final leafStart = Offset(c.dx - 4, c.dy + 90);
    path
      ..moveTo(leafStart.dx, leafStart.dy)
      ..quadraticBezierTo(
        leafStart.dx - 36,
        leafStart.dy - 8,
        leafStart.dx - 10,
        leafStart.dy + 28,
      )
      ..quadraticBezierTo(
        leafStart.dx + 8,
        leafStart.dy + 10,
        leafStart.dx,
        leafStart.dy,
      );
    return path;
  }

  Path _extract(Path source, double t) {
    t = t.clamp(0.0, 1.0);
    if (t <= 0) return Path();
    if (t >= 1) return source;
    final metrics = source.computeMetrics().toList();
    if (metrics.isEmpty) return Path();
    final total = metrics.fold<double>(0, (a, m) => a + m.length);
    var remain = total * t;
    final out = Path();
    for (final m in metrics) {
      if (remain <= 0) break;
      final take = math.min(remain, m.length);
      out.addPath(m.extractPath(0, take), Offset.zero);
      remain -= take;
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final stemProgress = (progress / 0.28).clamp(0.0, 1.0);
    final roseProgress = ((progress - 0.22) / 0.78).clamp(0.0, 1.0);

    final stemPaint = Paint()
      ..color = stem
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final roseStroke = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final roseFill = Paint()
      ..color = fill
      ..style = PaintingStyle.fill;

    final stemDrawn = _extract(_stemPath(size), stemProgress);
    canvas.drawPath(stemDrawn, stemPaint);

    final fullRose = _rosePath(size);
    if (roseProgress > 0.92) {
      canvas.drawPath(fullRose, roseFill);
    }
    final roseDrawn = _extract(fullRose, roseProgress);
    canvas.drawPath(roseDrawn, roseStroke);
  }

  @override
  bool shouldRepaint(covariant _RosePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.stroke != stroke ||
      oldDelegate.stem != stem;
}
