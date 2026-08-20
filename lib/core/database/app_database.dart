import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Color, Icons;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:coinly/core/constants/enums.dart';
import 'package:coinly/core/database/converters.dart';
import 'package:coinly/core/constants/category_defaults.dart';
import 'package:coinly/features/categories/data/tables/categories_table.dart';
import 'package:coinly/features/accounts/data/tables/accounts_table.dart';
import 'package:coinly/features/transactions/data/tables/transactions_table.dart';
import 'package:coinly/features/budgets/data/tables/budgets_table.dart';
import 'package:coinly/features/recurring/data/tables/recurring_rules_table.dart';
import 'package:coinly/features/goals/data/tables/goals_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Categories, Accounts, Transactions, Budgets, RecurringRules, Goals],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _seedDefaults();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await customStatement(
            'ALTER TABLE accounts ADD COLUMN initial_balance_minor INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            "ALTER TABLE accounts ADD COLUMN currency TEXT NOT NULL DEFAULT 'USD'",
          );
          await customStatement(
            'ALTER TABLE transactions ADD COLUMN amount_minor INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            "ALTER TABLE transactions ADD COLUMN currency TEXT NOT NULL DEFAULT 'USD'",
          );
          await customStatement(
            'ALTER TABLE recurring_rules ADD COLUMN amount_minor INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            "ALTER TABLE recurring_rules ADD COLUMN currency TEXT NOT NULL DEFAULT 'USD'",
          );
          await customStatement(
            'ALTER TABLE budgets ADD COLUMN amount_minor INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            "ALTER TABLE budgets ADD COLUMN currency TEXT NOT NULL DEFAULT 'USD'",
          );
          await _backfillMinorAmounts();
          await _createMoneyCompatibilityTriggers();
          await m.createTable(goals);
        }
        if (from < 3) {
          await customStatement(
            'ALTER TABLE transactions ADD COLUMN recurring_occurrence_key TEXT',
          );
          await customStatement('''
            UPDATE transactions
            SET recurring_occurrence_key = printf(
              '%d:%04d-%02d-%02d',
              recurring_rule_id,
              CAST(strftime('%Y', date) AS INTEGER),
              CAST(strftime('%m', date) AS INTEGER),
              CAST(strftime('%d', date) AS INTEGER)
            )
            WHERE recurring_rule_id IS NOT NULL
          ''');
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS transactions_recurring_occurrence_key_idx '
            'ON transactions(recurring_occurrence_key) '
            'WHERE recurring_occurrence_key IS NOT NULL',
          );
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        if (details.wasCreated) {
          await _createMoneyCompatibilityTriggers();
        }
      },
    );
  }

  Future<void> _backfillMinorAmounts() async {
    await customStatement(
      'UPDATE accounts SET initial_balance_minor = CAST(ROUND(initial_balance * 100) AS INTEGER)',
    );
    await customStatement(
      'UPDATE transactions SET amount_minor = CAST(ROUND(amount * 100) AS INTEGER)',
    );
    await customStatement(
      'UPDATE recurring_rules SET amount_minor = CAST(ROUND(amount * 100) AS INTEGER)',
    );
    await customStatement(
      'UPDATE budgets SET amount_minor = CAST(ROUND(amount * 100) AS INTEGER)',
    );
  }

  Future<void> _createMoneyCompatibilityTriggers() async {
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS accounts_money_compat_insert
      AFTER INSERT ON accounts
      WHEN NEW.initial_balance_minor = 0 AND NEW.initial_balance != 0
      BEGIN
        UPDATE accounts SET initial_balance_minor = CAST(ROUND(NEW.initial_balance * 100) AS INTEGER)
        WHERE id = NEW.id;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS transactions_money_compat_insert
      AFTER INSERT ON transactions
      WHEN NEW.amount_minor = 0 AND NEW.amount != 0
      BEGIN
        UPDATE transactions SET amount_minor = CAST(ROUND(NEW.amount * 100) AS INTEGER)
        WHERE id = NEW.id;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS recurring_money_compat_insert
      AFTER INSERT ON recurring_rules
      WHEN NEW.amount_minor = 0 AND NEW.amount != 0
      BEGIN
        UPDATE recurring_rules SET amount_minor = CAST(ROUND(NEW.amount * 100) AS INTEGER)
        WHERE id = NEW.id;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS budgets_money_compat_insert
      AFTER INSERT ON budgets
      WHEN NEW.amount_minor = 0 AND NEW.amount != 0
      BEGIN
        UPDATE budgets SET amount_minor = CAST(ROUND(NEW.amount * 100) AS INTEGER)
        WHERE id = NEW.id;
      END
    ''');
  }

  Future<void> _seedDefaults() async {
    // Seed default categories
    for (var i = 0; i < defaultCategories.length; i++) {
      final cat = defaultCategories[i];
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: cat.name,
          iconCodePoint: cat.icon.codePoint,
          iconFontFamily: Value(cat.icon.fontFamily ?? 'MaterialIcons'),
          color: cat.color.toARGB32(),
          isDefault: const Value(true),
          sortOrder: Value(i),
        ),
      );
    }

    // Seed default Cash account
    await into(accounts).insert(
      AccountsCompanion.insert(
        name: 'Cash',
        type: AccountType.cash,
        color: const Color(0xFF66BB6A).toARGB32(),
        iconCodePoint: Icons.account_balance_wallet.codePoint,
      ),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'coinly.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
