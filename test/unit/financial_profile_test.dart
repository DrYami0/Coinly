import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dime_money/core/constants/enums.dart';
import 'package:dime_money/features/settings/presentation/providers/settings_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists financial profile planning values', () async {
    final notifier = FinancialProfileNotifier();
    final nextDate = DateTime(2026, 9, 1);
    final profile = FinancialProfile(
      primaryCurrency: 'EUR',
      expectedIncomeMinor: 180000,
      incomeFrequency: IncomeFrequency.monthly,
      nextIncomeDate: nextDate,
      safetyBufferMinor: 50000,
      expectedVariableSpendingMinor: 70000,
      monthlySavingsCommitmentMinor: 20000,
    );

    await notifier.save(profile);
    final prefs = await SharedPreferences.getInstance();

    expect(prefs.getString('planning_currency'), 'EUR');
    expect(prefs.getInt('planning_income_minor'), 180000);
    expect(prefs.getString('planning_income_frequency'), 'monthly');
    expect(
      prefs.getString('planning_next_income_date'),
      nextDate.toIso8601String(),
    );
    expect(prefs.getInt('planning_safety_buffer_minor'), 50000);
    expect(prefs.getInt('planning_variable_spending_minor'), 70000);
    expect(prefs.getInt('planning_monthly_savings_minor'), 20000);
    expect(notifier.state?.hasIncomeConfiguration, isTrue);
  });

  test('no fixed income is an explicit valid income configuration', () async {
    final notifier = FinancialProfileNotifier();
    await notifier.save(
      const FinancialProfile(
        primaryCurrency: 'GBP',
        safetyBufferMinor: 100,
        expectedVariableSpendingMinor: 200,
        noFixedIncome: true,
      ),
    );

    expect(notifier.state?.hasIncomeConfiguration, isTrue);
    expect(notifier.state?.expectedIncomeMinor, isNull);
  });
}
