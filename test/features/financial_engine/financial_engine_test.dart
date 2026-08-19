import 'package:flutter_test/flutter_test.dart';
import 'package:dime_money/features/financial_engine/domain/financial_engine.dart';

void main() {
  const engine = FinancialEngine();

  test('calculates Safe-to-Spend correctly', () {
    const input = FinancialEngineInput(
      currentAvailableBalanceMinor: 100000,
      expectedIncomeMinor: 0,
      committedExpensesMinor: 20000,
      expectedVariableSpendingMinor: 30000,
      plannedSavingsMinor: 10000,
      safetyBufferMinor: 20000,
    );

    final result = engine.calculateSafeToSpend(input);

    expect(result.status, FinancialDataStatus.ready);
    expect(result.amountMinor, 20000);
  });

  test('never returns a negative Safe-to-Spend amount', () {
    const input = FinancialEngineInput(
      currentAvailableBalanceMinor: 10000,
      expectedIncomeMinor: 0,
      committedExpensesMinor: 20000,
      expectedVariableSpendingMinor: 10000,
      plannedSavingsMinor: 10000,
      safetyBufferMinor: 10000,
    );

    final result = engine.calculateSafeToSpend(input);

    expect(result.amountMinor, 0);
  });

  test('reports insufficient data without inventing a result', () {
    const input = FinancialEngineInput(
      currentAvailableBalanceMinor: 100000,
      expectedIncomeMinor: 0,
      committedExpensesMinor: 0,
      expectedVariableSpendingMinor: 0,
      plannedSavingsMinor: 0,
      safetyBufferMinor: 0,
      hasSufficientData: false,
      missingDataReasons: ['Add an account balance.'],
    );

    final result = engine.calculateSafeToSpend(input);

    expect(result.status, FinancialDataStatus.insufficientData);
    expect(result.amountMinor, 0);
    expect(result.reasons, ['Add an account balance.']);
  });

  test('classifies an affordable purchase as safe', () {
    const input = FinancialEngineInput(
      currentAvailableBalanceMinor: 100000,
      expectedIncomeMinor: 0,
      committedExpensesMinor: 20000,
      expectedVariableSpendingMinor: 30000,
      plannedSavingsMinor: 10000,
      safetyBufferMinor: 20000,
    );

    final result = engine.checkAffordability(
      input: input,
      purchaseAmountMinor: 20000,
    );

    expect(result.status, AffordabilityStatus.safe);
    expect(result.remainingAfterPurchaseMinor, 0);
  });

  test('classifies a purchase that consumes savings as a tradeoff', () {
    const input = FinancialEngineInput(
      currentAvailableBalanceMinor: 100000,
      expectedIncomeMinor: 0,
      committedExpensesMinor: 20000,
      expectedVariableSpendingMinor: 30000,
      plannedSavingsMinor: 10000,
      safetyBufferMinor: 20000,
    );

    final result = engine.checkAffordability(
      input: input,
      purchaseAmountMinor: 25000,
    );

    expect(result.status, AffordabilityStatus.possibleWithTradeoff);
  });

  test(
    'classifies a purchase below the protected margin as not recommended',
    () {
      const input = FinancialEngineInput(
        currentAvailableBalanceMinor: 100000,
        expectedIncomeMinor: 0,
        committedExpensesMinor: 20000,
        expectedVariableSpendingMinor: 30000,
        plannedSavingsMinor: 10000,
        safetyBufferMinor: 20000,
      );

      final result = engine.checkAffordability(
        input: input,
        purchaseAmountMinor: 60000,
      );

      expect(result.status, AffordabilityStatus.notRecommended);
    },
  );
}
