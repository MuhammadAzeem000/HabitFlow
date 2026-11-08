import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ad_policy.dart';
import 'ad_service.dart';

/// A place where a banner ad *may* appear (HF-018).
///
/// Renders nothing unless [AdPolicy] allows the placement and a banner has
/// finished loading. Loading starts after the first frame and is never
/// awaited by anything else; failures are swallowed. The slot can therefore
/// never delay a screen, block a tap, or crash the app.
class AdSlot extends ConsumerStatefulWidget {
  const AdSlot(this.placement, {super.key});

  final AdPlacement placement;

  @override
  ConsumerState<AdSlot> createState() => _AdSlotState();
}

class _AdSlotState extends ConsumerState<AdSlot> {
  Widget? _banner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoad());
  }

  Future<void> _maybeLoad() async {
    if (!mounted) return;
    final allowed = AdPolicy.canShow(
      widget.placement,
      AdContext(
        isPlus: ref.read(isPlusProvider),
        sinceLaunch: ref.read(sinceLaunchProvider)(),
      ),
    );
    if (!allowed) return;
    try {
      final banner = await ref
          .read(adServiceProvider)
          .loadBanner(widget.placement)
          .timeout(const Duration(seconds: 15));
      if (mounted && banner != null) setState(() => _banner = banner);
    } on Object {
      // An ad that fails to load is simply not shown.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Plus can switch on while the screen is open: hide immediately.
    final hidden = ref.watch(isPlusProvider) || _banner == null;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: hidden
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Semantics(
                container: true,
                label: 'Advertisement',
                child: _banner,
              ),
            ),
    );
  }
}
