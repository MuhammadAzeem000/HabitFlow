import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// HF-020: guards the offline-first, privacy-first design. Fails if a
/// networking, analytics, crash-reporting or tracking package is added, or
/// if app code opens network connections directly.
///
/// To add an approved package (e.g. the ad SDK for the free tier), add it to
/// [_allowedNetworkPackages] in the same PR, with a reason.
const _forbiddenPackagePrefixes = [
  'http',
  'dio',
  'chopper',
  'retrofit',
  'graphql',
  'firebase_',
  'cloud_firestore',
  'supabase',
  'amplitude',
  'mixpanel',
  'segment',
  'sentry',
  'appsflyer',
  'adjust',
];

/// Approved exceptions: none yet. Planned: an ad network SDK near release
/// (free tier), loaded only through lib/core/ads with AdPolicy rules.
const _allowedNetworkPackages = <String>{};

void main() {
  test('no networking, analytics or tracking dependencies', () {
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final deps = <String>[];
    var inDeps = false;
    for (final line in pubspec) {
      if (RegExp(r'^(dependencies|dev_dependencies):').hasMatch(line)) {
        inDeps = true;
        continue;
      }
      if (RegExp(r'^\S').hasMatch(line)) inDeps = false;
      final m = RegExp(r'^  ([a-z0-9_]+):').firstMatch(line);
      if (inDeps && m != null) deps.add(m.group(1)!);
    }
    expect(deps, contains('drift'), reason: 'sanity check of the parser');

    final offending = deps.where(
      (d) =>
          !_allowedNetworkPackages.contains(d) &&
          _forbiddenPackagePrefixes.any(d.startsWith),
    );
    expect(offending, isEmpty);
  });

  test('app code never opens network connections directly', () {
    final hits = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.endsWith('.g.dart')) continue;
      final text = file.readAsStringSync();
      for (final api in [
        'HttpClient(',
        'Socket.connect',
        'WebSocket.connect',
      ]) {
        if (text.contains(api)) hits.add('${file.path}: $api');
      }
    }
    expect(hits, isEmpty);
  });
}
