import 'package:flutter/material.dart';
import 'package:hux/hux.dart';

import '../../widgets/ds/ds_button.dart';
import '../../widgets/island_back_button.dart';

/// Showcase of Hux components available as the default design system.
class HuxComponentsScreen extends StatefulWidget {
  const HuxComponentsScreen({super.key});

  @override
  State<HuxComponentsScreen> createState() => _HuxComponentsScreenState();
}

class _HuxComponentsScreenState extends State<HuxComponentsScreen> {
  bool _switch = true;
  bool _check = false;
  double _slider = 40;
  String? _radio = 'a';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hux components'),
        leading: IslandBackButton.maybeOf(context),
        leadingWidth: IslandBackButton.leadingWidthOf(context),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'Buttons, inputs, and surfaces from Hux — used by default across Parinox.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          Text('Buttons', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              DsButton(onPressed: () {}, child: const Text('Primary')),
              DsButton(
                variant: DsButtonVariant.secondary,
                onPressed: () {},
                child: const Text('Secondary'),
              ),
              DsButton(
                variant: DsButtonVariant.outline,
                onPressed: () {},
                child: const Text('Outline'),
              ),
              DsButton(
                variant: DsButtonVariant.ghost,
                onPressed: () {},
                icon: Icons.favorite_outline,
                child: const Text('Ghost'),
              ),
              HuxButton(
                onPressed: () {},
                isLoading: true,
                child: const Text('Loading'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Inputs', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          const HuxInput(label: 'Email', hint: 'you@parinox.app'),
          const SizedBox(height: 12),
          const HuxTextarea(label: 'Bio', hint: 'Say something…'),
          const SizedBox(height: 24),
          Text('Controls', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              HuxSwitch(
                value: _switch,
                onChanged: (v) => setState(() => _switch = v),
              ),
              const SizedBox(width: 12),
              HuxCheckbox(
                value: _check,
                onChanged: (v) => setState(() => _check = v ?? false),
                label: 'Accept',
              ),
            ],
          ),
          const SizedBox(height: 12),
          HuxRadio<String>(
            value: 'a',
            groupValue: _radio,
            onChanged: (v) => setState(() => _radio = v),
            label: 'Option A',
          ),
          HuxRadio<String>(
            value: 'b',
            groupValue: _radio,
            onChanged: (v) => setState(() => _radio = v),
            label: 'Option B',
          ),
          const SizedBox(height: 12),
          HuxSlider(
            value: _slider,
            onChanged: (v) => setState(() => _slider = v),
            label: 'Intensity',
            showValue: true,
          ),
          const SizedBox(height: 24),
          Text('Feedback', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          const HuxAlert(
            variant: HuxAlertVariant.info,
            title: 'Heads up',
            message: 'Hux is the default design system for Parinox.',
          ),
          const SizedBox(height: 10),
          const HuxBadge(label: 'New'),
          const SizedBox(height: 10),
          const Row(
            children: [
              HuxLoading(),
              SizedBox(width: 16),
              Expanded(child: HuxProgress(value: 0.65)),
            ],
          ),
          const SizedBox(height: 24),
          Text('Surfaces', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          const HuxCard(
            title: 'Hux card',
            subtitle: 'Consistent container with semantic tokens',
            child: Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Use HuxCard, HuxDialog, HuxBottomSheet, and HuxTabs '
                'anywhere you need structured UI.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              HuxAvatar(name: 'Alice', size: HuxAvatarSize.large),
              SizedBox(width: 8),
              HuxAvatar(name: 'Bob', size: HuxAvatarSize.large),
              SizedBox(width: 8),
              HuxAvatarGroup(
                avatars: [
                  HuxAvatar(name: 'C'),
                  HuxAvatar(name: 'D'),
                  HuxAvatar(name: 'E'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          HuxTabs(
            tabs: [
              HuxTabItem(
                label: 'Chats',
                content: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Direct chats use primary accents.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              HuxTabItem(
                label: 'Groups',
                content: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Groups get teal accents.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              HuxTabItem(
                label: 'Channels',
                content: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Channels get amber accents.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          DsButton(
            expand: true,
            onPressed: () {
              context.showHuxSnackbar(
                message: 'Hux snackbar ready',
                variant: HuxSnackbarVariant.success,
              );
            },
            child: const Text('Show Hux snackbar'),
          ),
        ],
      ),
    );
  }
}
