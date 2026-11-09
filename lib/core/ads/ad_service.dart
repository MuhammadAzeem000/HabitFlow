import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utilities/current_day.dart';
import 'ad_policy.dart';

/// Supplies banner ads. The real implementation (an ad network SDK) is
/// added near release, together with Plus billing; until then the app uses
/// [NoAdService] and shows no ads.
abstract class AdService {
  /// Loads a banner for [placement]. Returns null when there is nothing to
  /// show. May be slow or throw; callers never wait on it to render.
  Future<Widget?> loadBanner(AdPlacement placement);
}

/// Shows nothing. The default until an ad network is integrated.
class NoAdService implements AdService {
  const NoAdService();

  @override
  Future<Widget?> loadBanner(AdPlacement placement) async => null;
}

final adServiceProvider = Provider<AdService>((ref) => const NoAdService());

/// Whether the user has Plus. Always false until billing exists.
final isPlusProvider = Provider<bool>((ref) => false);

/// Time since launch, for the no-ads-at-launch rule.
final sinceLaunchProvider = Provider<Duration Function()>(
  (ref) => ref.watch(monotonicClockProvider),
);
