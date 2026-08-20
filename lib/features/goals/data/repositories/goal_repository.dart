import 'package:drift/drift.dart';
import 'package:coinly/core/constants/enums.dart';
import 'package:coinly/core/database/app_database.dart';

class GoalRepository {
  final AppDatabase _db;

  GoalRepository(this._db);

  Stream<List<Goal>> watchActive() {
    return (_db.select(_db.goals)
          ..where((goal) => goal.status.equals(GoalStatus.active.name))
          ..orderBy([(goal) => OrderingTerm.asc(goal.targetDate)]))
        .watch();
  }

  Future<List<Goal>> getActive() {
    return (_db.select(_db.goals)
          ..where((goal) => goal.status.equals(GoalStatus.active.name))
          ..orderBy([(goal) => OrderingTerm.asc(goal.targetDate)]))
        .get();
  }

  Future<int> insert({
    required String name,
    required int targetMinor,
    required String currency,
    int currentMinor = 0,
    DateTime? targetDate,
    int? contributionMinor,
  }) {
    if (targetMinor <= 0) {
      throw ArgumentError.value(targetMinor, 'targetMinor');
    }
    if (currentMinor < 0 ||
        contributionMinor != null && contributionMinor < 0) {
      throw ArgumentError('Goal amounts cannot be negative.');
    }
    return _db
        .into(_db.goals)
        .insert(
          GoalsCompanion.insert(
            name: name,
            targetMinor: targetMinor,
            currentMinor: Value(currentMinor),
            currency: Value(currency),
            targetDate: Value(targetDate),
            contributionMinor: Value(contributionMinor),
          ),
        );
  }

  Future<void> update(Goal goal) {
    if (goal.targetMinor <= 0 || goal.currentMinor < 0) {
      throw ArgumentError('Goal amounts are invalid.');
    }
    return _db.update(_db.goals).replace(goal);
  }

  Future<int> deleteById(int id) {
    return (_db.delete(_db.goals)..where((goal) => goal.id.equals(id))).go();
  }
}
