import 'package:coinly/core/constants/enums.dart';
import 'package:coinly/core/recurring/occurrence.dart';
import 'package:coinly/features/financial_engine/domain/financial_engine.dart';

class PlannedCashFlowEvent {
  final DateTime date;
  final TransactionType type;
  final int amountMinor;
  final String currency;
  final String source;
  final String? occurrenceKey;

  const PlannedCashFlowEvent({
    required this.date,
    required this.type,
    required this.amountMinor,
    required this.currency,
    required this.source,
    this.occurrenceKey,
  });
}

class RecurringCashFlowRule {
  final DateTime startDate;
  final DateTime? endDate;
  final RecurrenceType recurrence;
  final TransactionType type;
  final int amountMinor;
  final String currency;
  final String source;
  final int? ruleId;

  const RecurringCashFlowRule({
    required this.startDate,
    required this.endDate,
    required this.recurrence,
    required this.type,
    required this.amountMinor,
    required this.currency,
    required this.source,
    this.ruleId,
  });
}

class SavingsGoalPlan {
  final int currentMinor;
  final int targetMinor;
  final int? contributionMinor;
  final DateTime? targetDate;
  final String currency;
  final GoalStatus status;

  const SavingsGoalPlan({
    required this.currentMinor,
    required this.targetMinor,
    required this.contributionMinor,
    required this.targetDate,
    required this.currency,
    required this.status,
  });
}

class ForecastInput {
  final int currentBalanceMinor;
  final String currency;
  final DateTime startDate;
  final int horizonDays;
  final List<RecurringCashFlowRule> recurringRules;
  final List<PlannedCashFlowEvent> knownEvents;
  final Set<String> materializedOccurrenceKeys;
  final List<SavingsGoalPlan> goals;
  final int safetyBufferMinor;
  final int expectedVariableSpendingMinor;
  final int monthlySavingsCommitmentMinor;
  final bool hasSufficientData;
  final List<String> missingDataReasons;

  const ForecastInput({
    required this.currentBalanceMinor,
    required this.currency,
    required this.startDate,
    required this.horizonDays,
    required this.recurringRules,
    required this.knownEvents,
    this.materializedOccurrenceKeys = const {},
    required this.goals,
    required this.safetyBufferMinor,
    required this.expectedVariableSpendingMinor,
    this.monthlySavingsCommitmentMinor = 0,
    this.hasSufficientData = true,
    this.missingDataReasons = const [],
  });
}

class ForecastPoint {
  final DateTime date;
  final int projectedBalanceMinor;
  final int incomeMinor;
  final int expenseMinor;

  const ForecastPoint({
    required this.date,
    required this.projectedBalanceMinor,
    required this.incomeMinor,
    required this.expenseMinor,
  });
}

class ForecastResult {
  final FinancialDataStatus status;
  final int currentBalanceMinor;
  final String currency;
  final List<String> reasons;
  final List<ForecastPoint> points;
  final int expectedIncomeMinor;
  final int committedExpensesMinor;
  final int plannedSavingsMinor;
  final int safetyBufferMinor;
  final int expectedVariableSpendingMinor;
  final int lowestProjectedBalanceMinor;
  final List<PlannedCashFlowEvent> upcomingEvents;

  const ForecastResult({
    required this.status,
    required this.currentBalanceMinor,
    required this.currency,
    required this.reasons,
    required this.points,
    required this.expectedIncomeMinor,
    required this.committedExpensesMinor,
    required this.plannedSavingsMinor,
    required this.safetyBufferMinor,
    required this.expectedVariableSpendingMinor,
    required this.lowestProjectedBalanceMinor,
    required this.upcomingEvents,
  });

  FinancialEngineInput toEngineInput({required int currentBalanceMinor}) {
    return FinancialEngineInput(
      currentAvailableBalanceMinor: currentBalanceMinor,
      expectedIncomeMinor: expectedIncomeMinor,
      committedExpensesMinor: committedExpensesMinor,
      expectedVariableSpendingMinor: expectedVariableSpendingMinor,
      plannedSavingsMinor: plannedSavingsMinor,
      safetyBufferMinor: safetyBufferMinor,
      hasSufficientData: status == FinancialDataStatus.ready,
      missingDataReasons: reasons,
    );
  }

  bool get isSavingsPlanCompatible =>
      status == FinancialDataStatus.ready &&
      lowestProjectedBalanceMinor >= safetyBufferMinor;
}

class ForecastService {
  const ForecastService();

  ForecastResult forecast(ForecastInput input) {
    if (!input.hasSufficientData) {
      return _insufficient(
        input,
        input.missingDataReasons.isEmpty
            ? 'More financial data is required for this forecast.'
            : input.missingDataReasons.join(' '),
      );
    }
    if (input.horizonDays <= 0) {
      return _insufficient(
        input,
        'Forecast horizon must be greater than zero.',
      );
    }

    final currencies = <String>{input.currency}
      ..addAll(input.recurringRules.map((rule) => rule.currency))
      ..addAll(input.knownEvents.map((event) => event.currency))
      ..addAll(input.goals.map((goal) => goal.currency));
    if (currencies.length > 1) {
      return _insufficient(
        input,
        'Currency conversion is required before forecasting.',
      );
    }

    final events = <DateTime, List<PlannedCashFlowEvent>>{};
    for (final rule in input.recurringRules) {
      for (final event in _expandRule(
        rule,
        input.startDate,
        input.horizonDays,
      )) {
        if (event.occurrenceKey != null &&
            input.materializedOccurrenceKeys.contains(event.occurrenceKey)) {
          continue;
        }
        events.putIfAbsent(_day(event.date), () => []).add(event);
      }
    }
    final plannedOccurrenceKeys = events.values
        .expand((dayEvents) => dayEvents)
        .map((event) => event.occurrenceKey)
        .whereType<String>()
        .toSet();
    for (final event in input.knownEvents) {
      if (event.occurrenceKey != null &&
          plannedOccurrenceKeys.contains(event.occurrenceKey)) {
        continue;
      }
      if (_withinHorizon(event.date, input.startDate, input.horizonDays)) {
        events.putIfAbsent(_day(event.date), () => []).add(event);
      }
    }
    for (final goal in input.goals) {
      if (goal.status != GoalStatus.active || goal.contributionMinor == null) {
        continue;
      }
      for (var day = 0; day < input.horizonDays; day++) {
        final date = input.startDate.add(Duration(days: day));
        if (date.day == 1 &&
            (goal.targetDate == null || !date.isAfter(goal.targetDate!))) {
          events
              .putIfAbsent(_day(date), () => [])
              .add(
                PlannedCashFlowEvent(
                  date: date,
                  type: TransactionType.expense,
                  amountMinor: goal.contributionMinor!,
                  currency: goal.currency,
                  source: 'savings-goal',
                ),
              );
        }
      }
    }
    if (input.monthlySavingsCommitmentMinor > 0) {
      events
          .putIfAbsent(_day(input.startDate), () => [])
          .add(
            PlannedCashFlowEvent(
              date: input.startDate,
              type: TransactionType.expense,
              amountMinor: input.monthlySavingsCommitmentMinor,
              currency: input.currency,
              source: 'profile-savings',
            ),
          );
    }

    var balance = input.currentBalanceMinor;
    var income = 0;
    var expenses = 0;
    var plannedSavings = 0;
    var lowest = balance;
    final dailyVariableBase =
        input.expectedVariableSpendingMinor ~/ input.horizonDays;
    final variableRemainder =
        input.expectedVariableSpendingMinor % input.horizonDays;
    final points = <ForecastPoint>[];
    final upcomingEvents =
        events.values.expand((dayEvents) => dayEvents).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    for (var day = 0; day < input.horizonDays; day++) {
      final date = input.startDate.add(Duration(days: day));
      var dayIncome = 0;
      var dayExpense = 0;
      final dayEvents = events[_day(date)] ?? const <PlannedCashFlowEvent>[];
      for (final event in dayEvents) {
        if (event.type == TransactionType.income) {
          balance += event.amountMinor;
          income += event.amountMinor;
          dayIncome += event.amountMinor;
        } else if (event.type == TransactionType.expense) {
          balance -= event.amountMinor;
          if (event.source != 'savings-goal' &&
              event.source != 'profile-savings') {
            expenses += event.amountMinor;
          }
          dayExpense += event.amountMinor;
          if (event.source == 'savings-goal' ||
              event.source == 'profile-savings') {
            plannedSavings += event.amountMinor;
          }
        }
      }
      final variableExpense =
          dailyVariableBase + (day < variableRemainder ? 1 : 0);
      balance -= variableExpense;
      dayExpense += variableExpense;
      if (balance < lowest) lowest = balance;
      points.add(
        ForecastPoint(
          date: date,
          projectedBalanceMinor: balance,
          incomeMinor: dayIncome,
          expenseMinor: dayExpense,
        ),
      );
    }

    return ForecastResult(
      status: FinancialDataStatus.ready,
      currentBalanceMinor: input.currentBalanceMinor,
      currency: input.currency,
      reasons: const [],
      points: points,
      expectedIncomeMinor: income,
      committedExpensesMinor: expenses,
      plannedSavingsMinor: plannedSavings,
      safetyBufferMinor: input.safetyBufferMinor,
      expectedVariableSpendingMinor: input.expectedVariableSpendingMinor,
      lowestProjectedBalanceMinor: lowest,
      upcomingEvents: upcomingEvents,
    );
  }

  ForecastResult _insufficient(ForecastInput input, String reason) {
    return ForecastResult(
      status: FinancialDataStatus.insufficientData,
      currentBalanceMinor: input.currentBalanceMinor,
      currency: input.currency,
      reasons: [reason],
      points: const [],
      expectedIncomeMinor: 0,
      committedExpensesMinor: 0,
      plannedSavingsMinor: 0,
      safetyBufferMinor: input.safetyBufferMinor,
      expectedVariableSpendingMinor: input.expectedVariableSpendingMinor,
      lowestProjectedBalanceMinor: input.currentBalanceMinor,
      upcomingEvents: const [],
    );
  }

  Iterable<PlannedCashFlowEvent> _expandRule(
    RecurringCashFlowRule rule,
    DateTime start,
    int horizonDays,
  ) sync* {
    var date = rule.startDate;
    final end = start.add(Duration(days: horizonDays));
    while (date.isBefore(start)) {
      date = _nextOccurrence(date, rule.recurrence);
    }
    while (date.isBefore(end)) {
      if (rule.endDate != null && date.isAfter(rule.endDate!)) return;
      yield PlannedCashFlowEvent(
        date: date,
        type: rule.type,
        amountMinor: rule.amountMinor,
        currency: rule.currency,
        source: rule.source,
          occurrenceKey: rule.ruleId == null
            ? null
            : recurringOccurrenceKey(rule.ruleId!, date),
      );
      date = _nextOccurrence(date, rule.recurrence);
    }
  }

  DateTime _nextOccurrence(DateTime date, RecurrenceType recurrence) {
    switch (recurrence) {
      case RecurrenceType.daily:
        return date.add(const Duration(days: 1));
      case RecurrenceType.weekly:
        return date.add(const Duration(days: 7));
      case RecurrenceType.biweekly:
        return date.add(const Duration(days: 14));
      case RecurrenceType.monthly:
        final nextMonth = DateTime(date.year, date.month + 1, 1);
        final maxDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
        return DateTime(
          nextMonth.year,
          nextMonth.month,
          date.day.clamp(1, maxDay),
        );
      case RecurrenceType.yearly:
        final maxDay = DateTime(date.year + 1, date.month + 1, 0).day;
        return DateTime(date.year + 1, date.month, date.day.clamp(1, maxDay));
    }
  }

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

  bool _withinHorizon(DateTime date, DateTime start, int days) {
    final end = start.add(Duration(days: days));
    return !date.isBefore(start) && date.isBefore(end);
  }
}
