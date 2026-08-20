import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coinly/app.dart';
import 'package:coinly/core/database/app_database.dart';
import 'package:coinly/core/providers/database_provider.dart';
import 'package:coinly/features/recurring/data/repositories/recurring_repository.dart';
import 'package:home_widget/home_widget.dart';
import 'package:coinly/core/utils/backup_service.dart';
import 'package:coinly/core/utils/widget_data.dart';
import 'package:coinly/core/supabase/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseConfig.initialize();

  // Set iOS App Group for widget data sharing (no-op on Android)
  try {
    await HomeWidget.setAppGroupId('group.com.priyanshu.dimeMoney');
  } catch (e) {
    debugPrint('HomeWidget setup failed: $e');
  }

  // Create DB and process recurring rules on app start
  final db = AppDatabase();
  final recurringRepo = RecurringRepository(db);
  await recurringRepo.processRules();

  // Database integrity check + auto backup
  final backupService = BackupService(db);
  final isHealthy = await backupService.checkIntegrity();
  if (!isHealthy) {
    debugPrint('WARNING: Database integrity check failed');
  }
  await backupService.autoBackup();

  // Update home screen widget data
  try {
    await updateWidgetData(db);
  } catch (e) {
    debugPrint('Widget data sync failed: $e');
  }

  // Check auto-update preference
  final prefs = await SharedPreferences.getInstance();
  final autoCheck = prefs.getBool('auto_check_update') ?? true;

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: DimeMoneyApp(checkForUpdate: autoCheck),
    ),
  );
}
