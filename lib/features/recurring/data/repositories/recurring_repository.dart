import 'package:drift/drift.dart';
import 'package:coinly/core/database/app_database.dart';
import 'package:coinly/core/constants/enums.dart';
import 'package:coinly/core/money/money.dart';
import 'package:coinly/core/recurring/occurrence.dart';

class RecurringRepository {
  final AppDatabase _db;

  RecurringRepository(this._db);

  Stream<List<RecurringRule>> watchAll() {
    return (_db.select(
      _db.recurringRules,
    )..orderBy([(r) => OrderingTerm.desc(r.createdAt)])).watch();
  }

  Future<List<RecurringRule>> getActive() {
    return (_db.select(
      _db.recurringRules,
    )..where((r) => r.isActive.equals(true))).get();
  }

  Future<int> insert({
    required TransactionType type,
    required double amount,
    String currency = defaultCurrencyCode,
    int? categoryId,
    required int accountId,
    String note = '',
    required RecurrenceType recurrence,
    required DateTime startDate,
    DateTime? endDate,
  }) {
    return _db
        .into(_db.recurringRules)
        .insert(
          RecurringRulesCompanion.insert(
            type: type,
            amount: amount,
            amountMinor: Value(majorToMinor(amount)),
            currency: Value(currency),
            categoryId: Value(categoryId),
            accountId: accountId,
            note: Value(note),
            recurrence: recurrence,
            startDate: startDate,
            endDate: Value(endDate),
          ),
        );
  }

  Future<void> update(RecurringRule rule) {
    return _db
        .update(_db.recurringRules)
        .replace(rule.copyWith(amountMinor: majorToMinor(rule.amount)));
  }

  Future<int> deleteById(int id) {
    return (_db.delete(_db.recurringRules)..where((r) => r.id.equals(id))).go();
  }

  /// Materialize due occurrences. [lastProcessed] is the last scheduled
  /// occurrence considered, not the time this method happened to run.
  Future<int> processRules() async {
    final rules = await getActive();
    int generated = 0;
    final now = DateTime.now();

    for (final rule in rules) {
      if (rule.endDate != null && rule.endDate!.isBefore(now)) continue;
      final materializationEnd =
          rule.endDate != null && rule.endDate!.isBefore(now)
          ? rule.endDate!
          : now;
      DateTime? lastMaterialized;
      for (final occurrence in recurringOccurrencesBetween(
        startDate: rule.startDate,
        recurrence: rule.recurrence,
        endDate: materializationEnd,
        after: rule.lastProcessed,
        includeStart: false,
      )) {
        final occurrenceKey = recurringOccurrenceKey(rule.id, occurrence);
        final insertedId = await _db
            .into(_db.transactions)
            .insert(
              TransactionsCompanion.insert(
                type: rule.type,
                amount: rule.amount,
                amountMinor: Value(
                  rule.amountMinor == 0
                      ? majorToMinor(rule.amount)
                      : rule.amountMinor,
                ),
                currency: Value(rule.currency),
                categoryId: Value(rule.categoryId),
                accountId: rule.accountId,
                note: Value(rule.note),
                date: occurrence,
                recurringRuleId: Value(rule.id),
                recurringOccurrenceKey: Value(occurrenceKey),
              ),
              mode: InsertMode.insertOrIgnore,
            );
        if (insertedId != 0) generated++;
        lastMaterialized = occurrence;
      }

      if (lastMaterialized != null) {
        await _db
            .update(_db.recurringRules)
            .replace(rule.copyWith(lastProcessed: Value(lastMaterialized)));
      }
    }

    return generated;
  }
}
