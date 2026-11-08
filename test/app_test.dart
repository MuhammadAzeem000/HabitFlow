import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/app/app.dart';

void main() {
  testWidgets('navigation shell switches between all tabs', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HabitFlowApp()));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);

    for (final (tab, title) in [
      ('Habits', 'Manage your habits'),
      ('Calendar', 'Your history'),
      ('Settings', 'Appearance'),
      ('Today', 'No habits yet'),
    ]) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget, reason: 'tab $tab');
    }
  });
}
