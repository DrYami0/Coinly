import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coinly/core/providers/database_provider.dart';
import 'package:coinly/core/database/app_database.dart';
import 'package:coinly/features/recurring/data/repositories/recurring_repository.dart';

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  return RecurringRepository(ref.watch(databaseProvider));
});

final allRecurringRulesProvider = StreamProvider<List<RecurringRule>>((ref) {
  return ref.watch(recurringRepositoryProvider).watchAll();
});
