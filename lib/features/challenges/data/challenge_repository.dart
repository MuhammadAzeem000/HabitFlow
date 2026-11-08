import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utilities/local_day.dart';

/// Local persistence for challenges (the 30-day challenge UI lands in
/// Phase 4; the storage is defined now so the schema is stable).
class ChallengeRepository {
  ChallengeRepository(this._db, {Uuid? uuid, DateTime Function()? clock})
    : _uuid = uuid ?? const Uuid(),
      _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _clock;

  Stream<List<Challenge>> watchAll() {
    return (_db.select(
      _db.challenges,
    )..orderBy([(c) => OrderingTerm.desc(c.createdAt)])).watch();
  }

  Future<String> create({
    required String title,
    required LocalDay startDate,
    String? habitId,
    int durationDays = 30,
  }) async {
    final now = _clock();
    final id = _uuid.v4();
    await _db
        .into(_db.challenges)
        .insert(
          ChallengesCompanion.insert(
            id: id,
            title: title,
            habitId: Value(habitId),
            durationDays: Value(durationDays),
            startDate: startDate.key,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> setStatus(
    String id,
    ChallengeStatus status, {
    LocalDay? pausedOn,
  }) async {
    final now = _clock();
    await (_db.update(_db.challenges)..where((c) => c.id.equals(id))).write(
      ChallengesCompanion(
        status: Value(status),
        pausedOn: Value(pausedOn?.key),
        completedAt: Value(status == ChallengeStatus.completed ? now : null),
        updatedAt: Value(now),
      ),
    );
  }
}
