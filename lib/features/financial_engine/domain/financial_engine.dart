enum FinancialDataStatus { ready, insufficientData }

enum AffordabilityStatus {
  safe,
  possibleWithTradeoff,
  notRecommended,
  insufficientData,
}

class FinancialEngineInput {
  final int currentAvailableBalanceMinor;
  final int expectedIncomeMinor;
  final int committedExpensesMinor;
  final int expectedVariableSpendingMinor;
  final int plannedSavingsMinor;
  final int safetyBufferMinor;
  final bool hasSufficientData;
  final List<String> missingDataReasons;

  const FinancialEngineInput({
    required this.currentAvailableBalanceMinor,
    required this.expectedIncomeMinor,
    required this.committedExpensesMinor,
    required this.expectedVariableSpendingMinor,
    required this.plannedSavingsMinor,
    required this.safetyBufferMinor,
    this.hasSufficientData = true,
    this.missingDataReasons = const [],
  });
}

class SafeToSpendResult {
  final FinancialDataStatus status;
  final int amountMinor;
  final List<String> reasons;

  const SafeToSpendResult({
    required this.status,
    required this.amountMinor,
    required this.reasons,
  });
}

class AffordabilityResult {
  final AffordabilityStatus status;
  final int purchaseAmountMinor;
  final int safeToSpendMinor;
  final int remainingAfterPurchaseMinor;
  final List<String> reasons;

  const AffordabilityResult({
    required this.status,
    required this.purchaseAmountMinor,
    required this.safeToSpendMinor,
    required this.remainingAfterPurchaseMinor,
    required this.reasons,
  });
}

class FinancialEngine {
  const FinancialEngine();

  SafeToSpendResult calculateSafeToSpend(FinancialEngineInput input) {
    if (!input.hasSufficientData) {
      return SafeToSpendResult(
        status: FinancialDataStatus.insufficientData,
        amountMinor: 0,
        reasons: input.missingDataReasons,
      );
    }

    final amount = _rawSafeToSpend(input);

    final reasons = <String>[];

    if (input.committedExpensesMinor > 0) {
      reasons.add('Future committed expenses are reserved.');
    }

    if (input.expectedVariableSpendingMinor > 0) {
      reasons.add('Expected variable spending is reserved.');
    }

    if (input.plannedSavingsMinor > 0) {
      reasons.add('Planned savings contributions are reserved.');
    }

    if (input.safetyBufferMinor > 0) {
      reasons.add('Your safety buffer is preserved.');
    }

    return SafeToSpendResult(
      status: FinancialDataStatus.ready,
      amountMinor: amount < 0 ? 0 : amount,
      reasons: reasons,
    );
  }

  AffordabilityResult checkAffordability({
    required FinancialEngineInput input,
    required int purchaseAmountMinor,
  }) {
    if (purchaseAmountMinor <= 0) {
      throw ArgumentError.value(
        purchaseAmountMinor,
        'purchaseAmountMinor',
        'Purchase amount must be greater than zero.',
      );
    }

    final safeToSpend = calculateSafeToSpend(input);
    if (safeToSpend.status == FinancialDataStatus.insufficientData) {
      return AffordabilityResult(
        status: AffordabilityStatus.insufficientData,
        purchaseAmountMinor: purchaseAmountMinor,
        safeToSpendMinor: 0,
        remainingAfterPurchaseMinor: 0,
        reasons: safeToSpend.reasons,
      );
    }

    final rawSafeToSpend = _rawSafeToSpend(input);
    final remainingAfterPurchase = rawSafeToSpend - purchaseAmountMinor;
    final withoutSavings =
        input.currentAvailableBalanceMinor +
        input.expectedIncomeMinor -
        input.committedExpensesMinor -
        input.expectedVariableSpendingMinor -
        input.safetyBufferMinor -
        purchaseAmountMinor;

    final reasons = <String>[];
    if (input.committedExpensesMinor > 0) {
      reasons.add('Future committed expenses remain reserved.');
    }
    if (input.safetyBufferMinor > 0) {
      reasons.add('The safety buffer remains protected.');
    }

    final status = remainingAfterPurchase >= 0
        ? AffordabilityStatus.safe
        : withoutSavings >= 0
        ? AffordabilityStatus.possibleWithTradeoff
        : AffordabilityStatus.notRecommended;

    if (status == AffordabilityStatus.possibleWithTradeoff &&
        input.plannedSavingsMinor > 0) {
      reasons.add('This purchase would reduce planned savings.');
    }
    if (status == AffordabilityStatus.notRecommended) {
      reasons.add('This purchase would leave less than the protected margin.');
    }

    return AffordabilityResult(
      status: status,
      purchaseAmountMinor: purchaseAmountMinor,
      safeToSpendMinor: safeToSpend.amountMinor,
      remainingAfterPurchaseMinor: remainingAfterPurchase,
      reasons: reasons,
    );
  }

  int _rawSafeToSpend(FinancialEngineInput input) {
    return input.currentAvailableBalanceMinor +
        input.expectedIncomeMinor -
        input.committedExpensesMinor -
        input.expectedVariableSpendingMinor -
        input.plannedSavingsMinor -
        input.safetyBufferMinor;
  }
}
