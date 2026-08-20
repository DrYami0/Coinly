import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show Value;
import 'package:coinly/core/constants/enums.dart';
import 'package:coinly/core/database/app_database.dart';
import 'package:coinly/core/money/money.dart';
import 'package:coinly/features/financial_engine/domain/financial_engine.dart';
import 'package:coinly/features/financial_engine/domain/forecast_service.dart';
import 'package:coinly/features/financial_engine/presentation/providers/forecast_provider.dart';
import 'package:coinly/features/settings/presentation/providers/settings_provider.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(activeGoalsProvider);
    final forecastAsync = ref.watch(authoritativeForecastProvider);
    final profile = ref.watch(financialProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings goals'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _showGoalEditor(context, ref, profile?.primaryCurrency),
        icon: const Icon(Icons.add),
        label: const Text('Add goal'),
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load goals: $error')),
        data: (goals) {
          if (goals.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No active goals yet. Create one to reserve savings in your forecast.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: goals.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _GoalCard(
              goal: goals[index],
              forecastReady:
                  forecastAsync.valueOrNull?.status ==
                  FinancialDataStatus.ready,
              contributionCompatible: _contributionCompatible(
                goals[index],
                forecastAsync.valueOrNull,
              ),
              onEdit: () => _showGoalEditor(
                context,
                ref,
                goals[index].currency,
                goal: goals[index],
              ),
              onStatus: (status) async {
                await ref
                    .read(goalRepositoryProvider)
                    .update(goals[index].copyWith(status: status));
                ref.invalidate(authoritativeForecastProvider);
              },
            ),
          );
        },
      ),
    );
  }

  bool _contributionCompatible(Goal goal, ForecastResult? forecast) {
    if (forecast == null ||
        forecast.status != FinancialDataStatus.ready ||
        goal.contributionMinor == null) {
      return false;
    }
    return forecast.isSavingsPlanCompatible;
  }

  Future<void> _showGoalEditor(
    BuildContext context,
    WidgetRef ref,
    String? defaultCurrency, {
    Goal? goal,
  }) async {
    final nameController = TextEditingController(text: goal?.name);
    final targetController = TextEditingController(
      text: goal == null ? '' : minorToMajorString(goal.targetMinor),
    );
    final currentController = TextEditingController(
      text: goal == null ? '0' : minorToMajorString(goal.currentMinor),
    );
    final contributionController = TextEditingController(
      text: goal?.contributionMinor == null
          ? ''
          : minorToMajorString(goal!.contributionMinor!),
    );
    var currency = goal?.currency ?? defaultCurrency;
    DateTime? targetDate = goal?.targetDate;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  goal == null ? 'New savings goal' : 'Edit savings goal',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Goal name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: currency,
                  decoration: const InputDecoration(
                    labelText: 'Currency',
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
                  onChanged: (value) => setState(() => currency = value),
                ),
                const SizedBox(height: 12),
                _MoneyField(
                  controller: targetController,
                  label: 'Target amount',
                  currency: currency,
                ),
                const SizedBox(height: 12),
                _MoneyField(
                  controller: currentController,
                  label: 'Already saved',
                  currency: currency,
                ),
                const SizedBox(height: 12),
                _MoneyField(
                  controller: contributionController,
                  label: 'Monthly contribution (optional)',
                  currency: currency,
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Target date (optional)'),
                  subtitle: Text(
                    targetDate == null
                        ? 'No target date'
                        : '${targetDate!.year}-${targetDate!.month.toString().padLeft(2, '0')}-${targetDate!.day.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      initialDate: targetDate ?? DateTime.now(),
                    );
                    if (picked != null) setState(() => targetDate = picked);
                  },
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final target = _parseMinor(targetController.text);
                    final current = _parseMinor(currentController.text) ?? 0;
                    final contribution = _parseMinor(
                      contributionController.text,
                    );
                    if (nameController.text.trim().isEmpty ||
                        currency == null ||
                        target == null ||
                        target <= 0 ||
                        current < 0 ||
                        contribution != null && contribution < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enter valid goal amounts and a name.'),
                        ),
                      );
                      return;
                    }
                    final repository = ref.read(goalRepositoryProvider);
                    if (goal == null) {
                      await repository.insert(
                        name: nameController.text.trim(),
                        targetMinor: target,
                        currentMinor: current,
                        contributionMinor: contribution,
                        targetDate: targetDate,
                        currency: currency!,
                      );
                    } else {
                      await repository.update(
                        goal.copyWith(
                          name: nameController.text.trim(),
                          targetMinor: target,
                          currentMinor: current,
                          contributionMinor: Value(contribution),
                          targetDate: Value(targetDate),
                          currency: currency!,
                        ),
                      );
                    }
                    ref.invalidate(authoritativeForecastProvider);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                  child: Text(goal == null ? 'Create goal' : 'Save goal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    nameController.dispose();
    targetController.dispose();
    currentController.dispose();
    contributionController.dispose();
  }

  int? _parseMinor(String value) {
    if (value.trim().isEmpty) return null;
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    return parsed == null ? null : majorToMinor(parsed);
  }
}

class _MoneyField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? currency;

  const _MoneyField({
    required this.controller,
    required this.label,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixText:
            '${currency == null ? '' : currencySymbolForCode(currency!)} ',
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final bool forecastReady;
  final bool contributionCompatible;
  final VoidCallback onEdit;
  final ValueChanged<GoalStatus> onStatus;

  const _GoalCard({
    required this.goal,
    required this.forecastReady,
    required this.contributionCompatible,
    required this.onEdit,
    required this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (goal.currentMinor / goal.targetMinor).clamp(0.0, 1.0);
    final symbol = currencySymbolForCode(goal.currency);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'pause') onStatus(GoalStatus.paused);
                    if (value == 'complete') onStatus(GoalStatus.completed);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'pause', child: Text('Pause')),
                    PopupMenuItem(value: 'complete', child: Text('Complete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(
              '$symbol${minorToMajorString(goal.currentMinor)} of $symbol${minorToMajorString(goal.targetMinor)}',
            ),
            if (goal.targetDate != null)
              Text(
                'Target: ${goal.targetDate!.year}-${goal.targetDate!.month.toString().padLeft(2, '0')}-${goal.targetDate!.day.toString().padLeft(2, '0')}',
              ),
            if (goal.contributionMinor != null)
              Text(
                forecastReady
                    ? contributionCompatible
                          ? 'Planned contribution fits the current forecast.'
                          : 'Planned contribution may exceed the current forecast.'
                    : 'Complete financial setup to check contribution compatibility.',
                style: TextStyle(
                  color: forecastReady && contributionCompatible
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
