import 'package:flutter/foundation.dart';

/// Where an ad may appear (HF-018).
///
/// Deliberately limited to calm, secondary screens. There is no placement
/// for Today, app launch, habit completion, the habit editor or the
/// challenge flow, so ads there cannot be requested at all. There is also
/// no interstitial (full-screen) format.
enum AdPlacement {
  /// Below the list on the Habits screen.
  habitsListFooter,

  /// Below the month on the Calendar screen.
  calendarFooter,

  /// At the bottom of Settings.
  settingsFooter,
}

/// Facts the policy needs about the current session.
@immutable
class AdContext {
  const AdContext({required this.isPlus, required this.sinceLaunch});

  /// Plus subscribers never see ads.
  final bool isPlus;

  /// Time since the app process started.
  final Duration sinceLaunch;
}

/// The ad rules from the MVP plan (§11), as code:
///
/// * No ads for Plus subscribers.
/// * No ad at launch: nothing is shown in the first [launchGrace].
/// * Only the placements in [AdPlacement] exist — never Today, never before
///   or during a habit completion, never on history or the free challenge.
/// * Banners only; no interstitials.
///
/// Loading is handled elsewhere and is always asynchronous: an ad that is
/// slow or fails simply never appears and never blocks the UI.
abstract final class AdPolicy {
  static const launchGrace = Duration(seconds: 10);

  static bool canShow(AdPlacement placement, AdContext context) {
    if (context.isPlus) return false;
    if (context.sinceLaunch < launchGrace) return false;
    return switch (placement) {
      AdPlacement.habitsListFooter ||
      AdPlacement.calendarFooter ||
      AdPlacement.settingsFooter => true,
    };
  }
}
