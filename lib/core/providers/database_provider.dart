import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coinly/core/database/app_database.dart';
import 'package:coinly/core/utils/backup_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(databaseProvider));
});
