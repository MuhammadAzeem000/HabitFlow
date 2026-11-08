import 'package:habitflow/core/notifications/reminder_planner.dart';
import 'package:habitflow/core/notifications/reminder_service.dart';

/// Records what the app asks the reminder service to do.
class FakeReminderService implements ReminderService {
  FakeReminderService({this.grantPermission = true});

  bool grantPermission;
  int permissionRequests = 0;
  final List<List<PlannedReminder>> replaced = [];

  List<PlannedReminder> get latest =>
      replaced.isEmpty ? const [] : replaced.last;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grantPermission;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    replaced.add(List.of(reminders));
  }
}
