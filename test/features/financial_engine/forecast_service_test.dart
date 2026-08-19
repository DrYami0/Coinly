import 'package:flutter_test/flutter_test.dart';
import 'package:dime_money/core/constants/enums.dart';
import 'package:dime_money/features/financial_engine/domain/financial_engine.dart';
import 'package:dime_money/features/financial_engine/domain/forecast_service.dart';

void main() {
  const service = ForecastService();
  final start = DateTime(2024, 1, 31);

  ForecastInput input({
    int balance = 10000,
    int horizon = 31,
    List<RecurringCashFlowRule> rules = const [],
    List<PlannedCashFlowEvent> events = const [],
    List<SavingsGoalPlan> goals = const [],
    int variable = 0,
    int buffer = 0,
    int savings = 0,
    bool sufficient = true,
    List<String> missing = const [],
  }) {
    return ForecastInput(
      currentBalanceMinor: balance,
      currency: 'USD',
      startDate: start,
      horizonDays: horizon,
      recurringRules: rules,
      knownEvents: events,
      goals: goals,
      safetyBufferMinor: buffer,
      expectedVariableSpendingMinor: variable,
      monthlySavingsCommitmentMinor: savings,
      hasSufficientData: sufficient,
      missingDataReasons: missing,
    );
  }

  test('projects a positive balance and future income', () {
    final result = service.forecast(
      input(
        rules: [
          RecurringCashFlowRule(
            startDate: start,
            endDate: null,
            recurrence: RecurrenceType.monthly,
            type: TransactionType.income,
            amountMinor: 5000,
            currency: 'USD',
            source: 'salary',
          ),
        ],
      ),
    );

    expect(result.status, FinancialDataStatus.ready);
    expect(result.expectedIncomeMinor, 10000);
    expect(result.points.last.projectedBalanceMinor, 20000);
  });

  test('includes recurring expenses, known events, and variable spending', () {
    final result = service.forecast(
      input(
        horizon: 10,
        variable: 1000,
        rules: [
          RecurringCashFlowRule(
            startDate: start,
            endDate: null,
            recurrence: RecurrenceType.weekly,
            type: TransactionType.expense,
            amountMinor: 500,
            currency: 'USD',
            source: 'rent',
          ),
        ],
        events: [
          PlannedCashFlowEvent(
            date: start.add(const Duration(days: 2)),
            type: TransactionType.expense,
            amountMinor: 1000,
            currency: 'USD',
            source: 'planned',
          ),
        ],
      ),
    );

    expect(result.committedExpensesMinor, 2000);
    expect(result.expectedVariableSpendingMinor, 1000);
    expect(result.points.last.projectedBalanceMinor, 7000);
  });

  test('adds active goal contributions but ignores completed goals', () {
    final result = service.forecast(
      input(
        horizon: 62,
        goals: [
          SavingsGoalPlan(
            currentMinor: 0,
            targetMinor: 10000,
            contributionMinor: 300,
            targetDate: DateTime(2024, 4),
            currency: 'USD',
            status: GoalStatus.active,
          ),
          SavingsGoalPlan(
            currentMinor: 10000,
            targetMinor: 10000,
            contributionMinor: 300,
            targetDate: null,
            currency: 'USD',
            status: GoalStatus.completed,
          ),
        ],
      ),
    );

    expect(result.plannedSavingsMinor, 900);
    expect(result.points.last.projectedBalanceMinor, 9100);
  });

  test('rejects mixed currencies without an implicit conversion', () {
    final result = service.forecast(
      input(
        rules: [
          RecurringCashFlowRule(
            startDate: start,
            endDate: null,
            recurrence: RecurrenceType.monthly,
            type: TransactionType.income,
            amountMinor: 1,
            currency: 'EUR',
            source: 'salary',
          ),
        ],
      ),
    );

    expect(result.status, FinancialDataStatus.insufficientData);
    expect(result.reasons.single, contains('Currency conversion'));
  });

  test('handles month boundaries and leap years deterministically', () {
    final result = service.forecast(
      input(
        horizon: 32,
        rules: [
          RecurringCashFlowRule(
            startDate: DateTime(2024, 1, 31),
            endDate: null,
            recurrence: RecurrenceType.monthly,
            type: TransactionType.income,
            amountMinor: 100,
            currency: 'USD',
            source: 'income',
          ),
        ],
      ),
    );

    expect(result.expectedIncomeMinor, 200);
    expect(result.points[28].date, DateTime(2024, 2, 28));
  });

  test('rejects empty or insufficient data explicitly', () {
    final result = service.forecast(
      input(sufficient: false, missing: const ['Add an account balance.']),
    );

    expect(result.status, FinancialDataStatus.insufficientData);
    expect(result.reasons, ['Add an account balance.']);
  });

  test('supports zero, negative projected, and very large minor amounts', () {
    final zero = service.forecast(input(balance: 0, horizon: 1));
    expect(zero.points.single.projectedBalanceMinor, 0);

    final negative = service.forecast(
      input(
        balance: 10,
        horizon: 1,
        events: [
          PlannedCashFlowEvent(
            date: start,
            type: TransactionType.expense,
            amountMinor: 100,
            currency: 'USD',
            source: 'obligation',
          ),
        ],
      ),
    );
    expect(negative.lowestProjectedBalanceMinor, -90);

    final large = service.forecast(input(balance: 900000000000000, horizon: 1));
    expect(large.points.single.projectedBalanceMinor, 900000000000000);
  });

  test('converts forecast output into the authoritative engine input', () {
    final result = service.forecast(input(buffer: 200));
    final engineInput = result.toEngineInput(currentBalanceMinor: 10000);
    final safe = const FinancialEngine().calculateSafeToSpend(engineInput);

    expect(safe.amountMinor, 9800);
  });

  test('marks a savings plan incompatible when it breaches the buffer', () {
    final result = service.forecast(
      input(
        balance: 1000,
        horizon: 1,
        buffer: 900,
        savings: 200,
        goals: [
          SavingsGoalPlan(
            currentMinor: 0,
            targetMinor: 10000,
            contributionMinor: 200,
            targetDate: null,
            currency: 'USD',
            status: GoalStatus.active,
          ),
        ],
      ),
    );

    expect(result.status, FinancialDataStatus.ready);
    expect(result.isSavingsPlanCompatible, isFalse);
    expect(result.plannedSavingsMinor, 200);
  });

  test(
    'safe-to-spend includes income, savings, variable spending and buffer',
    () {
      final result = service.forecast(
        input(
          balance: 10000,
          horizon: 1,
          buffer: 1000,
          variable: 500,
          savings: 500,
          goals: [
            SavingsGoalPlan(
              currentMinor: 0,
              targetMinor: 10000,
              contributionMinor: 500,
              targetDate: null,
              currency: 'USD',
              status: GoalStatus.active,
            ),
          ],
          rules: [
            RecurringCashFlowRule(
              startDate: start,
              endDate: null,
              recurrence: RecurrenceType.daily,
              type: TransactionType.income,
              amountMinor: 2000,
              currency: 'USD',
              source: 'income',
            ),
          ],
        ),
      );

      final safe = const FinancialEngine().calculateSafeToSpend(
        result.toEngineInput(currentBalanceMinor: result.currentBalanceMinor),
      );
      expect(safe.amountMinor, 10000);
    },
  );
}
