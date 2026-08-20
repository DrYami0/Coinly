import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dime_money/core/database/app_database.dart';
import 'package:dime_money/core/constants/enums.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('home_widget');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
  });

  group('Migration scaffolding', () {
    test('schema v1 creates successfully with in-memory DB', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      // Trigger migration by querying
      final categories = await db.select(db.categories).get();
      expect(categories, isNotEmpty); // seeded defaults
      await db.close();
    });

    test('PRAGMA foreign_keys is ON after open', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      // Trigger beforeOpen
      await db.select(db.categories).get();

      final result = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(result.read<int>('foreign_keys'), 1);
      await db.close();
    });

    test('schema v2 exposes minor units and preserves legacy writes', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final account = await db.select(db.accounts).getSingle();
      final transactionId = await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              type: TransactionType.expense,
              amount: 12.34,
              accountId: account.id,
              date: DateTime(2026, 8, 19),
            ),
          );

      final updatedAccount = await (db.select(
        db.accounts,
      )..where((row) => row.id.equals(account.id))).getSingle();
      final transaction = await (db.select(
        db.transactions,
      )..where((row) => row.id.equals(transactionId))).getSingle();

      expect(updatedAccount.initialBalanceMinor, 0);
      expect(transaction.amountMinor, 1234);
      expect(transaction.currency, 'USD');
      await db.close();
    });
  });
}
