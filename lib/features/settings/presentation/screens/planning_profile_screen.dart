import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:coinly/core/constants/enums.dart';
import 'package:coinly/core/money/money.dart';
import 'package:coinly/features/financial_engine/presentation/providers/forecast_provider.dart';
import 'package:coinly/features/settings/presentation/providers/settings_provider.dart';

class PlanningProfileScreen extends ConsumerStatefulWidget {
  const PlanningProfileScreen({super.key});

  @override
  ConsumerState<PlanningProfileScreen> createState() =>
      _PlanningProfileScreenState();
}

class _PlanningProfileScreenState extends ConsumerState<PlanningProfileScreen> {
  final _incomeController = TextEditingController();
  final _bufferController = TextEditingController();
  final _variableController = TextEditingController();
  final _savingsController = TextEditingController();
  String? _currency;
  IncomeFrequency _frequency = IncomeFrequency.monthly;
  DateTime _nextIncomeDate = DateTime.now();
  bool _noFixedIncome = false;
  bool _hydrated = false;

  @override
  void dispose() {
    _incomeController.dispose();
    _bufferController.dispose();
    _variableController.dispose();
    _savingsController.dispose();
    super.dispose();
  }

  void _hydrate(FinancialProfile? profile) {
    if (_hydrated || profile == null) return;
    _hydrated = true;
    _currency = profile.primaryCurrency;
    _frequency = profile.incomeFrequency ?? IncomeFrequency.monthly;
    _nextIncomeDate = profile.nextIncomeDate ?? DateTime.now();
    _noFixedIncome = profile.noFixedIncome;
    _incomeController.text = _format(profile.expectedIncomeMinor);
    _bufferController.text = _format(profile.safetyBufferMinor);
    _variableController.text = _format(profile.expectedVariableSpendingMinor);
    _savingsController.text = _format(profile.monthlySavingsCommitmentMinor);
  }

  String _format(int? amountMinor) =>
      amountMinor == null ? '' : minorToMajorString(amountMinor);

  int? _parse(String value) {
    if (value.trim().isEmpty) return null;
    final amount = double.tryParse(value.trim().replaceAll(',', '.'));
    return amount == null ? null : majorToMinor(amount);
  }

  Future<void> _save() async {
    final income = _parse(_incomeController.text);
    final buffer = _parse(_bufferController.text);
    final variable = _parse(_variableController.text);
    final savings = _parse(_savingsController.text);
    final hasIncome = _noFixedIncome || income != null && income > 0;
    if (_currency == null || buffer == null || variable == null || !hasIncome) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choose a currency, safety buffer, variable spending, and income setup.',
          ),
        ),
      );
      return;
    }

    final profile = FinancialProfile(
      primaryCurrency: _currency,
      expectedIncomeMinor: _noFixedIncome ? null : income,
      incomeFrequency: _noFixedIncome ? null : _frequency,
      nextIncomeDate: _noFixedIncome ? null : _nextIncomeDate,
      safetyBufferMinor: buffer,
      expectedVariableSpendingMinor: variable,
      monthlySavingsCommitmentMinor: savings,
      noFixedIncome: _noFixedIncome,
    );
    await ref.read(financialProfileProvider.notifier).save(profile);
    await ref
        .read(currencySymbolProvider.notifier)
        .set(currencySymbolForCode(profile.primaryCurrency!));
    ref.invalidate(authoritativeForecastProvider);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Financial setup saved.')));
      context.pop();
    }
  }

  Future<void> _pickIncomeDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3660)),
      initialDate: _nextIncomeDate.isBefore(DateTime.now())
          ? DateTime.now()
          : _nextIncomeDate,
    );
    if (date != null) setState(() => _nextIncomeDate = date);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(financialProfileProvider);
    _hydrate(profile);
    final symbol = _currency == null ? '' : currencySymbolForCode(_currency!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial setup'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Complete your financial setup',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'These values power Safe-to-Spend. The app will not invent missing estimates.',
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: const InputDecoration(
              labelText: 'Primary currency',
              border: OutlineInputBorder(),
            ),
            items: supportedCurrencyCodes
                .map(
                  (code) => DropdownMenuItem(
                    value: code,
                    child: Text('$code (${currencySymbolForCode(code)})'),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _currency = value),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('I do not have fixed income'),
            value: _noFixedIncome,
            onChanged: (value) => setState(() => _noFixedIncome = value),
          ),
          if (!_noFixedIncome) ...[
            TextField(
              controller: _incomeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Expected income',
                prefixText: '$symbol ',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<IncomeFrequency>(
              initialValue: _frequency,
              decoration: const InputDecoration(
                labelText: 'Income frequency',
                border: OutlineInputBorder(),
              ),
              items: IncomeFrequency.values
                  .map(
                    (frequency) => DropdownMenuItem(
                      value: frequency,
                      child: Text(_label(frequency.name)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _frequency = value);
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Next expected income'),
              subtitle: Text(
                '${_nextIncomeDate.year}-${_nextIncomeDate.month.toString().padLeft(2, '0')}-${_nextIncomeDate.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickIncomeDate,
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _bufferController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Safety buffer',
              helperText: 'Amount to keep protected',
              prefixText: '$symbol ',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _variableController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Expected variable spending',
              helperText: 'For this forecast period; no estimate is invented',
              prefixText: '$symbol ',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _savingsController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monthly savings commitment (optional)',
              prefixText: '$symbol ',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Save financial setup'),
          ),
        ],
      ),
    );
  }

  String _label(String value) => value[0].toUpperCase() + value.substring(1);
}
