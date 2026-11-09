/// Route paths.
abstract final class Routes {
  static const home = '/';
  static const habits = '/habits';
  static const calendar = '/calendar';
  static const settings = '/settings';

  static const newHabit = '/habit/new';
  static const editHabitPattern = '/habit/:id/edit';
  static String editHabit(String id) => '/habit/$id/edit';

  static const challenges = '/challenges';
  static const plans = '/plans';
}
