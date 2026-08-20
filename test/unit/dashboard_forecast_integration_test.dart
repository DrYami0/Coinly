import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dime_money/core/database/app_database.dart';
import 'package:dime_money/core/constants/enums.dart';
import 'package:dime_money/features/financial_engine/domain/financial_engine.dart';
import 'package:dime_money/features/financial_engine/presentation/providers/forecast_provider.dart';
import 'package:dime_money/core/providers/database_provider.dart';
import 'package:dime_money/features/settings/presentation/providers/settings_provider.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({
      'planning_currency': 'USD',
      'planning_income_minor': 10000,
      'planning_income_frequency': 'monthly',
      'planning_next_income_date': DateTime.now().toIso8601String(),
      'planning_safety_buffer_minor': 1000,
      'planning_variable_spending_minor': 500,
      'planning_no_fixed_income': false,
    });
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.select(db.accounts).get();
  });

  tearDown(() => db.close());

  test(
    'dashboard forecast provider returns a complete planning forecast',
    () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          financialProfileProvider.overrideWith(
            (ref) => _FixedProfileNotifier(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final forecast = await container.read(
        authoritativeForecastProvider.future,
      );

      expect(forecast.status, FinancialDataStatus.ready);
      expect(forecast.currency, 'USD');
      expect(forecast.expectedIncomeMinor, greaterThan(0));
      expect(forecast.safetyBufferMinor, 1000);
      expect(forecast.expectedVariableSpendingMinor, 500);
      expect(forecast.points, isNotEmpty);
    },
  );
}

class _FixedProfileNotifier extends FinancialProfileNotifier {
  _FixedProfileNotifier() : super(load: false) {
    state = FinancialProfile(
      primaryCurrency: 'USD',
      expectedIncomeMinor: 10000,
      incomeFrequency: IncomeFrequency.monthly,
      nextIncomeDate: DateTime.now().add(const Duration(days: 1)),
      safetyBufferMinor: 1000,
      expectedVariableSpendingMinor: 500,
      noFixedIncome: false,
    );
  }
}
