import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dime_money/core/constants/enums.dart';
import 'package:dime_money/core/database/app_database.dart';
import 'package:dime_money/core/recurring/occurrence.dart';
import 'package:dime_money/features/financial_engine/domain/forecast_service.dart';
import 'package:dime_money/features/recurring/data/repositories/recurring_repository.dart';

void main() {
  late AppDatabase db;
  late RecurringRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = RecurringRepository(db);
  });

  tearDown(() => db.close());

  test('future recurring events appear exactly once in a forecast', () {
    final start = DateTime(2026, 9, 1);
    final result = const ForecastService().forecast(
      ForecastInput(
        currentBalanceMinor: 10000,
        currency: 'USD',
        startDate: start,
        horizonDays: 31,
        recurringRules: [
          RecurringCashFlowRule(
            startDate: start,
            endDate: null,
            recurrence: RecurrenceType.monthly,
            type: TransactionType.expense,
            amountMinor: 1000,
            currency: 'USD',
            source: 'rule-1',
            ruleId: 1,
          ),
        ],
        knownEvents: const [],
        goals: const [],
        safetyBufferMinor: 0,
        expectedVariableSpendingMinor: 0,
      ),
    );

    expect(
      result.upcomingEvents.where((event) => event.source == 'rule-1'),
      hasLength(2),
    );
    expect(result.committedExpensesMinor, 2000);
  });

  test('materialized actual occurrence is excluded from planned forecast', () {
    final start = DateTime(2026, 9, 1);
    final key = recurringOccurrenceKey(1, start);
    final result = const ForecastService().forecast(
      ForecastInput(
        currentBalanceMinor: 9000,
        currency: 'USD',
        startDate: start,
        horizonDays: 31,
        recurringRules: [
          RecurringCashFlowRule(
            startDate: start,
            endDate: null,
            recurrence: RecurrenceType.monthly,
            type: TransactionType.expense,
            amountMinor: 1000,
            currency: 'USD',
            source: 'rule-1',
            ruleId: 1,
          ),
        ],
        knownEvents: const [],
        materializedOccurrenceKeys: {key},
        goals: const [],
        safetyBufferMinor: 0,
        expectedVariableSpendingMinor: 0,
      ),
    );

    expect(result.upcomingEvents, hasLength(1));
    expect(result.committedExpensesMinor, 1000);
  });

  test(
    'restarting materialization does not create duplicate transactions',
    () async {
      final accounts = await db.select(db.accounts).get();
      final ruleId = await repository.insert(
        type: TransactionType.expense,
        amount: 10,
        accountId: accounts.first.id,
        recurrence: RecurrenceType.daily,
        startDate: DateTime.now().subtract(const Duration(days: 3)),
      );

      final first = await repository.processRules();
      final second = await repository.processRules();
      final transactions = await db.select(db.transactions).get();

      expect(first, greaterThan(0));
      expect(second, 0);
      expect(
        transactions.map((t) => t.recurringOccurrenceKey).toSet(),
        hasLength(transactions.length),
      );
      expect(transactions.every((t) => t.recurringRuleId == ruleId), isTrue);
    },
  );

  test(
    'recurring income materializes and forecasts with the same semantics',
    () async {
      final accounts = await db.select(db.accounts).get();
      await repository.insert(
        type: TransactionType.income,
        amount: 100,
        accountId: accounts.first.id,
        recurrence: RecurrenceType.monthly,
        startDate: DateTime.now().subtract(const Duration(days: 40)),
      );

      final generated = await repository.processRules();
      final transactions = await db.select(db.transactions).get();

      expect(generated, greaterThan(0));
      expect(
        transactions.every((t) => t.type == TransactionType.income),
        isTrue,
      );
      expect(
        transactions.every((t) => t.recurringOccurrenceKey != null),
        isTrue,
      );
    },
  );

  test(
    'missed occurrences are materialized once and lastProcessed is scheduled date',
    () async {
      final accounts = await db.select(db.accounts).get();
      final start = DateTime.now().subtract(const Duration(days: 5));
      final ruleId = await repository.insert(
        type: TransactionType.expense,
        amount: 10,
        accountId: accounts.first.id,
        recurrence: RecurrenceType.daily,
        startDate: start,
      );

      await repository.processRules();
      final rule = await (db.select(
        db.recurringRules,
      )..where((row) => row.id.equals(ruleId))).getSingle();
      final occurrences = await db.select(db.transactions).get();

      expect(rule.lastProcessed, isNotNull);
      expect(rule.lastProcessed!.isBefore(DateTime.now()), isTrue);
      expect(occurrences.length, greaterThanOrEqualTo(5));
    },
  );

  test('monthly and yearly boundaries are deterministic', () {
    final monthly = recurringOccurrencesBetween(
      startDate: DateTime(2024, 1, 31),
      recurrence: RecurrenceType.monthly,
      endDate: DateTime(2024, 4, 30),
    ).toList();
    final yearly = recurringOccurrencesBetween(
      startDate: DateTime(2024, 2, 29),
      recurrence: RecurrenceType.yearly,
      endDate: DateTime(2026, 3, 1),
    ).toList();

    expect(monthly, [
      DateTime(2024, 1, 31),
      DateTime(2024, 2, 29),
      DateTime(2024, 3, 29),
      DateTime(2024, 4, 29),
    ]);
    expect(yearly, [
      DateTime(2024, 2, 29),
      DateTime(2025, 2, 28),
      DateTime(2026, 2, 28),
    ]);
  });
}
