import 'package:flutter/material.dart';

import '../domain/plans.dart';

/// Transparent free vs. future-premium breakdown (HF-017). There is no
/// purchase flow: this screen only sets expectations honestly.
class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Free & Plus')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Everything you use today is free, and your habits and '
                'history will never be locked behind a payment.',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const _Heading('Free forever'),
          for (final f in freeForeverFeatures)
            _FeatureTile(feature: f, trailing: const _Tag('Free')),
          const _Heading('HabitFlow Plus'),
          Text(
            'Ideas we may offer later as an optional upgrade. None of these '
            'exist yet.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          for (final f in plannedPlusFeatures)
            _FeatureTile(feature: f, trailing: const PlusBadge()),
          const _Heading('Our promise'),
          const _Promise('There is nothing to buy right now.'),
          const _Promise(
            'If Plus launches, the price and any trial terms will be shown '
            'clearly before you pay.',
          ),
          const _Promise('Features that are free today will stay free.'),
          const _Promise(
            'A challenge or routine you start for free will never be '
            'interrupted by a paywall.',
          ),
          const _Promise(
            'If the free version shows ads, they will never interrupt '
            'completing a habit or slow the app down.',
          ),
        ],
      ),
    );
  }
}

/// "Plus · coming later" label for features that don't exist yet.
class PlusBadge extends StatelessWidget {
  const PlusBadge({super.key});

  @override
  Widget build(BuildContext context) => const _Tag('Coming later');
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: scheme.onSecondaryContainer),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.feature, required this.trailing});

  final PlanFeature feature;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(feature.icon),
    title: Text(feature.title),
    subtitle: Text(feature.detail),
    trailing: trailing,
  );
}

class _Promise extends StatelessWidget {
  const _Promise(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.verified_outlined,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
