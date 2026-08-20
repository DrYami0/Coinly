import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coinly/core/providers/database_provider.dart';
import 'package:coinly/core/money/money.dart';
import 'package:coinly/core/constants/enums.dart';
import 'package:coinly/core/database/app_database.dart';
import 'package:coinly/features/financial_engine/domain/forecast_service.dart';
import 'package:coinly/features/goals/data/repositories/goal_repository.dart';
import 'package:coinly/features/recurring/data/repositories/recurring_repository.dart';
import 'package:coinly/features/transactions/data/repositories/transaction_repository.dart';
import 'package:coinly/features/accounts/data/repositories/account_repository.dart';
import 'package:coinly/features/settings/presentation/providers/settings_provider.dart';

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepository(ref.watch(databaseProvider));
});

final activeGoalsProvider = StreamProvider<List<Goal>>((ref) {
  return ref.watch(goalRepositoryProvider).watchActive();
});

final forecastServiceProvider = Provider<ForecastService>((ref) {
  return const ForecastService();
});

final authoritativeForecastProvider = FutureProvider<ForecastResult>((
  ref,
) async {
  final profile = ref.watch(financialProfileProvider);
  final database = ref.watch(databaseProvider);
  final accountRepository = AccountRepository(database);
  final transactionRepository = TransactionRepository(database);
  final recurringRepository = RecurringRepository(database);
  final goalRepository = GoalRepository(database);
  final accounts = await accountRepository.getAll();
  final now = DateTime.now();
  final horizonDays = DateTime(
    now.year,
    now.month + 1,
    1,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;
  final rules = await recurringRepository.getActive();
  final goals = await goalRepository.getActive();
  final futureTransactions = await transactionRepository.getAfter(now);
  final materializedOccurrenceKeys = await transactionRepository
      .getMaterializedRecurringOccurrenceKeys();
  final service = ref.watch(forecastServiceProvider);

  if (profile == null) {
    return service.forecast(
      ForecastInput(
        currentBalanceMinor: 0,
        currency: 'UNCONFIGURED',
        startDate: now,
        horizonDays: horizonDays,
        recurringRules: const [],
        knownEvents: const [],
        materializedOccurrenceKeys: materializedOccurrenceKeys,
        goals: const [],
        safetyBufferMinor: 0,
        expectedVariableSpendingMinor: 0,
        hasSufficientData: false,
        missingDataReasons: const [
          'Complete your financial setup by choosing a currency and planning values.',
        ],
      ),
    );
  }

  if (accounts.isEmpty) {
    return service.forecast(
      ForecastInput(
        currentBalanceMinor: 0,
        currency: profile.primaryCurrency ?? 'UNCONFIGURED',
        startDate: now,
        horizonDays: horizonDays,
        recurringRules: const [],
        knownEvents: const [],
        materializedOccurrenceKeys: materializedOccurrenceKeys,
        goals: const [],
        safetyBufferMinor: 0,
        expectedVariableSpendingMinor: 0,
        hasSufficientData: false,
        missingDataReasons: const ['Add at least one account balance.'],
      ),
    );
  }

  final currency = profile.primaryCurrency ?? accounts.first.currency;
  final hasOneCurrency = accounts.every(
    (account) => account.currency == currency,
  );
  final hasProfileCurrency = accounts.every(
    (account) => account.currency == profile.primaryCurrency,
  );
  final currentBalanceMinor = await accountRepository
      .computeTotalBalanceMinor();
  final recurringRules = rules
      .map(
        (rule) => RecurringCashFlowRule(
          startDate: rule.startDate,
          endDate: rule.endDate,
          recurrence: rule.recurrence,
          type: rule.type,
          amountMinor: rule.amountMinor == 0
              ? majorToMinor(rule.amount)
              : rule.amountMinor,
          currency: rule.currency,
          source: 'recurring-${rule.id}',
          ruleId: rule.id,
        ),
      )
      .toList();
  if (profile.hasIncomeConfiguration &&
      !profile.noFixedIncome &&
      profile.expectedIncomeMinor != null &&
      profile.incomeFrequency != null &&
      profile.nextIncomeDate != null) {
    recurringRules.add(
      RecurringCashFlowRule(
        startDate: profile.nextIncomeDate!,
        endDate: null,
        recurrence: _recurrenceFor(profile.incomeFrequency!),
        type: TransactionType.income,
        amountMinor: profile.expectedIncomeMinor!,
        currency: profile.primaryCurrency!,
        source: 'profile-income',
      ),
    );
  }
  return service.forecast(
    ForecastInput(
      currentBalanceMinor: currentBalanceMinor,
      currency: currency,
      startDate: now,
      horizonDays: horizonDays,
      recurringRules: recurringRules,
      knownEvents: futureTransactions
          .map(
            (transaction) => PlannedCashFlowEvent(
              date: transaction.date,
              type: transaction.type,
              amountMinor: transaction.amountMinor == 0
                  ? majorToMinor(transaction.amount)
                  : transaction.amountMinor,
              currency: transaction.currency,
              source: 'transaction-${transaction.id}',
              occurrenceKey: transaction.recurringOccurrenceKey,
            ),
          )
          .toList(),
      materializedOccurrenceKeys: materializedOccurrenceKeys,
      goals: goals
          .map(
            (goal) => SavingsGoalPlan(
              currentMinor: goal.currentMinor,
              targetMinor: goal.targetMinor,
              contributionMinor: goal.contributionMinor,
              targetDate: goal.targetDate,
              currency: goal.currency,
              status: goal.status,
            ),
          )
          .toList(),
      safetyBufferMinor: profile.safetyBufferMinor ?? 0,
      expectedVariableSpendingMinor: profile.expectedVariableSpendingMinor ?? 0,
      monthlySavingsCommitmentMinor: profile.monthlySavingsCommitmentMinor ?? 0,
      hasSufficientData:
          hasOneCurrency &&
          hasProfileCurrency &&
          profile.hasIncomeConfiguration &&
          profile.safetyBufferMinor != null &&
          profile.expectedVariableSpendingMinor != null,
      missingDataReasons: !hasOneCurrency || !hasProfileCurrency
          ? const [
              'Accounts use different currencies without conversion rates.',
            ]
          : [
              if (!profile.hasIncomeConfiguration)
                'Configure recurring income or select no fixed income.',
              if (profile.safetyBufferMinor == null)
                'Set a safety buffer to protect essential obligations.',
              if (profile.expectedVariableSpendingMinor == null)
                'Enter expected variable spending; no estimate will be invented.',
            ],
    ),
  );
});

RecurrenceType _recurrenceFor(IncomeFrequency frequency) {
  switch (frequency) {
    case IncomeFrequency.weekly:
      return RecurrenceType.weekly;
    case IncomeFrequency.biweekly:
      return RecurrenceType.biweekly;
    case IncomeFrequency.monthly:
      return RecurrenceType.monthly;
    case IncomeFrequency.yearly:
      return RecurrenceType.yearly;
  }
}
