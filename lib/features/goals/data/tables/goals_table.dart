import 'package:drift/drift.dart';
import 'package:coinly/core/database/converters.dart';

class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get targetMinor => integer()();
  IntColumn get currentMinor => integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  IntColumn get contributionMinor => integer().nullable()();
  TextColumn get status => text()
      .map(const GoalStatusConverter())
      .withDefault(const Constant('active'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
