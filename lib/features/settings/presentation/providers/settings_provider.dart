import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coinly/core/constants/enums.dart';

class FinancialProfile {
  final String? primaryCurrency;
  final int? expectedIncomeMinor;
  final IncomeFrequency? incomeFrequency;
  final DateTime? nextIncomeDate;
  final int? safetyBufferMinor;
  final int? expectedVariableSpendingMinor;
  final int? monthlySavingsCommitmentMinor;
  final bool noFixedIncome;

  const FinancialProfile({
    this.primaryCurrency,
    this.expectedIncomeMinor,
    this.incomeFrequency,
    this.nextIncomeDate,
    this.safetyBufferMinor,
    this.expectedVariableSpendingMinor,
    this.monthlySavingsCommitmentMinor,
    this.noFixedIncome = false,
  });

  bool get hasIncomeConfiguration =>
      noFixedIncome ||
      expectedIncomeMinor != null &&
          expectedIncomeMinor! > 0 &&
          incomeFrequency != null &&
          nextIncomeDate != null;
}

final financialProfileProvider =
    StateNotifierProvider<FinancialProfileNotifier, FinancialProfile?>((ref) {
      return FinancialProfileNotifier();
    });

class FinancialProfileNotifier extends StateNotifier<FinancialProfile?> {
  FinancialProfileNotifier({bool load = true}) : super(null) {
    if (load) _load();
  }

  static const _currencyKey = 'planning_currency';
  static const _incomeKey = 'planning_income_minor';
  static const _frequencyKey = 'planning_income_frequency';
  static const _nextIncomeKey = 'planning_next_income_date';
  static const _bufferKey = 'planning_safety_buffer_minor';
  static const _variableKey = 'planning_variable_spending_minor';
  static const _savingsKey = 'planning_monthly_savings_minor';
  static const _noIncomeKey = 'planning_no_fixed_income';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final frequencyName = prefs.getString(_frequencyKey);
    final dateValue = prefs.getString(_nextIncomeKey);
    state = FinancialProfile(
      primaryCurrency: prefs.getString(_currencyKey),
      expectedIncomeMinor: prefs.getInt(_incomeKey),
      incomeFrequency: frequencyName == null
          ? null
          : IncomeFrequency.values.cast<IncomeFrequency?>().firstWhere(
              (frequency) => frequency?.name == frequencyName,
              orElse: () => null,
            ),
      nextIncomeDate: dateValue == null ? null : DateTime.tryParse(dateValue),
      safetyBufferMinor: prefs.getInt(_bufferKey),
      expectedVariableSpendingMinor: prefs.getInt(_variableKey),
      monthlySavingsCommitmentMinor: prefs.getInt(_savingsKey),
      noFixedIncome: prefs.getBool(_noIncomeKey) ?? false,
    );
  }

  Future<void> save(FinancialProfile profile) async {
    if (profile.primaryCurrency == null ||
        profile.safetyBufferMinor == null ||
        profile.expectedVariableSpendingMinor == null ||
        profile.safetyBufferMinor! < 0 ||
        profile.expectedVariableSpendingMinor! < 0 ||
        !profile.hasIncomeConfiguration) {
      throw ArgumentError('Financial profile is incomplete or invalid.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, profile.primaryCurrency!);
    if (profile.expectedIncomeMinor == null) {
      await prefs.remove(_incomeKey);
    } else {
      await prefs.setInt(_incomeKey, profile.expectedIncomeMinor!);
    }
    if (profile.incomeFrequency == null) {
      await prefs.remove(_frequencyKey);
    } else {
      await prefs.setString(_frequencyKey, profile.incomeFrequency!.name);
    }
    if (profile.nextIncomeDate == null) {
      await prefs.remove(_nextIncomeKey);
    } else {
      await prefs.setString(
        _nextIncomeKey,
        profile.nextIncomeDate!.toIso8601String(),
      );
    }
    await _saveNullableInt(prefs, _bufferKey, profile.safetyBufferMinor);
    await _saveNullableInt(
      prefs,
      _variableKey,
      profile.expectedVariableSpendingMinor,
    );
    await _saveNullableInt(
      prefs,
      _savingsKey,
      profile.monthlySavingsCommitmentMinor,
    );
    await prefs.setBool(_noIncomeKey, profile.noFixedIncome);
    state = profile;
  }

  Future<void> _saveNullableInt(
    SharedPreferences prefs,
    String key,
    int? value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setInt(key, value);
    }
  }
}

final incomeEnabledProvider =
    StateNotifierProvider<IncomeEnabledNotifier, bool>((ref) {
      return IncomeEnabledNotifier();
    });

class IncomeEnabledNotifier extends StateNotifier<bool> {
  IncomeEnabledNotifier() : super(false) {
    _load();
  }

  static const _key = 'income_enabled';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }
}

final currencySymbolProvider =
    StateNotifierProvider<CurrencySymbolNotifier, String>((ref) {
      return CurrencySymbolNotifier();
    });

class CurrencySymbolNotifier extends StateNotifier<String> {
  CurrencySymbolNotifier() : super('\$') {
    _load();
  }

  static const _key = 'currency_symbol';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key) ?? '\$';
  }

  Future<void> set(String symbol) async {
    state = symbol;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, symbol);
  }
}

final autoCheckUpdateProvider =
    StateNotifierProvider<AutoCheckUpdateNotifier, bool>((ref) {
      return AutoCheckUpdateNotifier();
    });

class AutoCheckUpdateNotifier extends StateNotifier<bool> {
  AutoCheckUpdateNotifier() : super(true) {
    _load();
  }

  static const _key = 'auto_check_update';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }
}

final biometricEnabledProvider =
    StateNotifierProvider<BiometricEnabledNotifier, bool>((ref) {
      return BiometricEnabledNotifier();
    });

class BiometricEnabledNotifier extends StateNotifier<bool> {
  BiometricEnabledNotifier() : super(false) {
    _load();
  }

  static const _key = 'biometric_enabled';
  final _auth = LocalAuthentication();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<bool> toggle() async {
    if (!state) {
      // Enabling: verify biometrics first
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isSupported) return false;

      final didAuth = await _auth.authenticate(
        localizedReason: 'Verify to enable biometric lock',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (!didAuth) return false;
    }

    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
    return true;
  }

  Future<void> disable() async {
    state = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, false);
  }
}
