import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:coinly/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:coinly/features/dashboard/presentation/widgets/balance_header.dart';
import 'package:coinly/features/dashboard/presentation/widgets/spending_donut.dart';
import 'package:coinly/features/dashboard/presentation/widgets/period_toggle.dart';
import 'package:coinly/features/dashboard/presentation/widgets/recent_transactions.dart';
import 'package:coinly/features/financial_engine/domain/financial_engine.dart';
import 'package:coinly/features/financial_engine/presentation/providers/forecast_provider.dart';
import 'package:coinly/core/constants/enums.dart';
import 'package:coinly/core/money/money.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardTotalsProvider);
          ref.invalidate(dashboardCategoryBreakdownProvider);
          ref.invalidate(totalBalanceProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              centerTitle: false,
              toolbarHeight: 64,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Text('Coinly'),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 80),
              sliver: SliverList.list(
                children: [
                  const Gap(4),
                  const BalanceHeader(),
                  const Gap(24),
                  const _PlanningSummary(),
                  const Gap(24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FilledButton.icon(
                      onPressed: () => context.push('/affordability'),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Can I afford it?'),
                    ),
                  ),
                  const Gap(24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Spending',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const PeriodToggle(),
                      ],
                    ),
                  ),
                  const Gap(16),
                  const SpendingDonut(),
                  const Gap(24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Recent',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Gap(8),
                  const RecentTransactions(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanningSummary extends ConsumerWidget {
  const _PlanningSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecastAsync = ref.watch(authoritativeForecastProvider);
    final goalsAsync = ref.watch(activeGoalsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: forecastAsync.when(
        loading: () => const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: LinearProgressIndicator(),
          ),
        ),
        error: (error, _) => Card(
          child: ListTile(
            leading: const Icon(Icons.error_outline),
            title: const Text('Forecast unavailable'),
            subtitle: Text('$error'),
            trailing: IconButton(
              onPressed: () => ref.invalidate(authoritativeForecastProvider),
              icon: const Icon(Icons.refresh),
            ),
          ),
        ),
        data: (forecast) {
          if (forecast.status == FinancialDataStatus.insufficientData) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Complete your financial setup'),
                subtitle: Text(forecast.reasons.join(' ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/planning'),
              ),
            );
          }
          final input = forecast.toEngineInput(
            currentBalanceMinor: forecast.currentBalanceMinor,
          );
          final safe = const FinancialEngine().calculateSafeToSpend(input);
          final symbol = currencySymbolForCode(forecast.currency);
          final upcoming = forecast.upcomingEvents.take(3).toList();
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Safe to spend',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$symbol${minorToMajorString(safe.amountMinor)}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Text(
                        'Balance $symbol${minorToMajorString(forecast.currentBalanceMinor)}',
                      ),
                      Text(
                        'Income $symbol${minorToMajorString(forecast.expectedIncomeMinor)}',
                      ),
                      Text(
                        'Obligations $symbol${minorToMajorString(forecast.committedExpensesMinor)}',
                      ),
                      Text(
                        'Savings $symbol${minorToMajorString(forecast.plannedSavingsMinor)}',
                      ),
                      Text(
                        'Buffer $symbol${minorToMajorString(forecast.safetyBufferMinor)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Projected balance at period end: $symbol${minorToMajorString(forecast.points.last.projectedBalanceMinor)}',
                  ),
                  if (upcoming.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Upcoming'),
                    ...upcoming.map(
                      (event) => Text(
                        '${event.date.month}/${event.date.day}  ${event.type == TransactionType.income ? '+' : '-'}$symbol${minorToMajorString(event.amountMinor)}  ${event.source}',
                      ),
                    ),
                  ],
                  goalsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (goals) => goals.isEmpty
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              '${goals.length} active savings goal${goals.length == 1 ? '' : 's'}',
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
