import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:coinly/features/financial_engine/domain/financial_engine.dart';
import 'package:coinly/features/financial_engine/presentation/providers/forecast_provider.dart';
import 'package:coinly/features/settings/presentation/providers/settings_provider.dart';

class AffordabilityScreen extends ConsumerStatefulWidget {
  const AffordabilityScreen({super.key});

  @override
  ConsumerState<AffordabilityScreen> createState() =>
      _AffordabilityScreenState();
}

class _AffordabilityScreenState extends ConsumerState<AffordabilityScreen> {
  final _amountController = TextEditingController();
  AffordabilityResult? _result;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _check() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _result = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than zero.')),
      );
      return;
    }

    final forecast = ref.read(authoritativeForecastProvider).valueOrNull;
    if (forecast == null) return;
    final result = const FinancialEngine().checkAffordability(
      input: forecast.toEngineInput(
        currentBalanceMinor: forecast.points.isEmpty
            ? 0
            : forecast.points.first.projectedBalanceMinor,
      ),
      purchaseAmountMinor: (amount * 100).round(),
    );
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final forecastAsync = ref.watch(authoritativeForecastProvider);
    final currency = ref.watch(currencySymbolProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Can I afford it?'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: forecastAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(authoritativeForecastProvider),
            icon: const Icon(Icons.refresh),
            label: Text('Retry: $error'),
          ),
        ),
        data: (forecast) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (forecast.status == FinancialDataStatus.insufficientData) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Complete your financial setup'),
                  subtitle: Text(forecast.reasons.join(' ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/planning'),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Check a purchase against your currently tracked balance.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Purchase amount',
                prefixText: '$currency ',
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _check(),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed:
                  forecast.status == FinancialDataStatus.ready &&
                      forecastAsync.hasValue
                  ? _check
                  : null,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Check purchase'),
            ),
            const SizedBox(height: 20),
            if (_result case final result?) _ResultCard(result: result),
            const SizedBox(height: 20),
            Text(
              'Forecast currency: ${forecast.currency}. Add a safety buffer and variable-spending history for a complete decision.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final AffordabilityResult result;

  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final (title, icon, color) = switch (result.status) {
      AffordabilityStatus.safe => (
        'You can safely afford this',
        Icons.check_circle,
        Colors.green,
      ),
      AffordabilityStatus.possibleWithTradeoff => (
        'You can, but it has a trade-off',
        Icons.warning_amber,
        Colors.orange,
      ),
      AffordabilityStatus.notRecommended => (
        'Not recommended right now',
        Icons.error,
        Colors.red,
      ),
      AffordabilityStatus.insufficientData => (
        'Need more information',
        Icons.help,
        Colors.blue,
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            if (result.reasons.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...result.reasons.map(
                (reason) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(reason),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
