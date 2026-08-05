import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../theme/theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/ds/ds_chrome.dart';
import 'chat/room_list_screen.dart';
import 'explore/explore_screen.dart';
import 'music/music_screen.dart';
import 'profile/profile_screen.dart';
import 'settings/settings_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  late final PageController _page = PageController();
  late final NotchBottomBarController _notchController =
      NotchBottomBarController(index: 0);

  static const _pages = <Widget>[
    RoomListScreen(),
    ExploreScreen(),
    MusicScreen(),
    ProfileScreen(),
    SettingsScreen(),
  ];

  static const _destinations = <AppNavDestination>[
    AppNavDestination(
      label: 'Chats',
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
    ),
    AppNavDestination(
      label: 'Explore',
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
    ),
    AppNavDestination(
      label: 'Music',
      icon: Icons.library_music_outlined,
      selectedIcon: Icons.library_music,
    ),
    AppNavDestination(
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
    AppNavDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  @override
  void dispose() {
    _page.dispose();
    _notchController.dispose();
    super.dispose();
  }

  void _setIndex(int i) {
    if (_index == i) return;
    setState(() => _index = i);
    _page.animateToPage(
      i,
      duration: AppMotion.normal,
      curve: AppMotion.curve,
    );
    if (_notchController.index != i) {
      _notchController.jumpTo(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final navStyle = settings.navBarStyle;
    final floatingChrome = navStyle == NavBarStyle.floating ||
        navStyle == NavBarStyle.curved ||
        navStyle == NavBarStyle.notch;

    return DsScaffold(
      extendBody: floatingChrome,
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _page,
              onPageChanged: (i) {
                setState(() => _index = i);
                if (_notchController.index != i) {
                  _notchController.jumpTo(i);
                }
              },
              children: [
                for (final page in _pages)
                  AnimatedBuilder(
                    animation: _page,
                    builder: (context, child) {
                      // Soft parallax-ish fade while swiping.
                      return child!;
                    },
                    child: page,
                  ),
              ],
            ),
          ),
          MusicMiniPlayer(
            onOpen: () => _setIndex(2),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        index: _index,
        onChanged: _setIndex,
        style: navStyle,
        destinations: _destinations,
        notchController: _notchController,
      ),
    );
  }
}
