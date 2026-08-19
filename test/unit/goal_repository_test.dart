import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dime_money/core/constants/enums.dart';
import 'package:dime_money/core/database/app_database.dart';
import 'package:dime_money/features/goals/data/repositories/goal_repository.dart';

void main() {
  late AppDatabase db;
  late GoalRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = GoalRepository(db);
  });

  tearDown(() => db.close());

  test('persists goal fields and defaults to active', () async {
    final id = await repository.insert(
      name: 'Emergency fund',
      targetMinor: 100000,
      currentMinor: 25000,
      currency: 'USD',
      targetDate: DateTime(2025, 12, 31),
      contributionMinor: 5000,
    );

    final goal = await (db.select(
      db.goals,
    )..where((row) => row.id.equals(id))).getSingle();

    expect(goal.name, 'Emergency fund');
    expect(goal.targetMinor, 100000);
    expect(goal.currentMinor, 25000);
    expect(goal.currency, 'USD');
    expect(goal.targetDate, DateTime(2025, 12, 31));
    expect(goal.contributionMinor, 5000);
    expect(goal.status, GoalStatus.active);
  });

  test('rejects invalid goal amounts', () {
    expect(
      () => repository.insert(name: 'Invalid', targetMinor: 0, currency: 'USD'),
      throwsArgumentError,
    );
  });

  test('active query excludes completed goals', () async {
    final id = await repository.insert(
      name: 'Finished',
      targetMinor: 100,
      currentMinor: 100,
      currency: 'USD',
    );
    final goal = await (db.select(
      db.goals,
    )..where((row) => row.id.equals(id))).getSingle();
    await repository.update(goal.copyWith(status: GoalStatus.completed));

    expect(await repository.getActive(), isEmpty);
  });
}
