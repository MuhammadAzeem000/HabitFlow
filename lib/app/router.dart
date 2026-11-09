import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/calendar/presentation/calendar_screen.dart';
import '../features/challenges/presentation/challenges_screen.dart';
import '../features/dashboard/presentation/home_screen.dart';
import '../features/habits/presentation/habit_editor_screen.dart';
import '../features/habits/presentation/habits_screen.dart';
import '../features/settings/presentation/plans_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../shared/widgets/app_shell.dart';
import '../shared/widgets/snackbar_route_observer.dart';
import 'routes.dart';

export 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.home,
    observers: [SnackBarRouteObserver()],
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.habits,
                builder: (context, state) => const HabitsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.calendar,
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      // Full-screen routes (above the bottom navigation).
      GoRoute(
        path: Routes.newHabit,
        builder: (context, state) => const HabitEditorScreen(),
      ),
      GoRoute(
        path: Routes.plans,
        builder: (context, state) => const PlansScreen(),
      ),
      GoRoute(
        path: Routes.challenges,
        builder: (context, state) => const ChallengesScreen(),
      ),
      GoRoute(
        path: Routes.editHabitPattern,
        builder: (context, state) =>
            HabitEditorScreen(habitId: state.pathParameters['id']),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
