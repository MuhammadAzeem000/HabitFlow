import 'package:flutter/material.dart';

/// A feature listed on the Free & Plus screen (HF-017).
@immutable
class PlanFeature {
  const PlanFeature(this.icon, this.title, this.detail);

  final IconData icon;
  final String title;
  final String detail;
}

/// Always free. Never move an item from here to [plannedPlusFeatures]:
/// users must never lose access to something they already rely on.
const freeForeverFeatures = <PlanFeature>[
  PlanFeature(
    Icons.check_circle_outline,
    'Daily habit tracking',
    'Create, schedule and complete habits — offline, no account',
  ),
  PlanFeature(
    Icons.history,
    'Your full history',
    'Calendar, streaks and weekly consistency, always accessible',
  ),
  PlanFeature(
    Icons.notifications_none,
    'Reminders',
    'Optional reminders at the times you choose',
  ),
  PlanFeature(
    Icons.self_improvement,
    'Rest days and pauses',
    'Take breaks without losing progress',
  ),
  PlanFeature(
    Icons.flag_outlined,
    '30-day challenge',
    'Completable for free, start to finish',
  ),
];

/// Ideas for a possible future "Plus" tier. Nothing here exists yet and
/// nothing is locked.
///
/// Product rule: the free tier is supported by non-intrusive ads; Plus adds
/// value on top. Plus never restricts the core habit-tracking experience
/// (no habit limits, no locked history).
const plannedPlusFeatures = <PlanFeature>[
  PlanFeature(Icons.block, 'Ad-free', 'No ads anywhere in the app'),
  PlanFeature(
    Icons.insights,
    'Advanced analytics',
    'Long-term trends, patterns and deeper insights',
  ),
  PlanFeature(
    Icons.palette_outlined,
    'Premium themes',
    'Extra colour themes and styles',
  ),
  PlanFeature(
    Icons.route_outlined,
    'Advanced routines',
    'Group habits into routines with richer scheduling',
  ),
];
