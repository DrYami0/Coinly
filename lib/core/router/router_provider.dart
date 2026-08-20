import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:coinly/features/auth/presentation/providers/auth_provider.dart';
import 'package:coinly/features/auth/presentation/screens/auth_screen.dart';
import 'package:coinly/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:coinly/features/transactions/presentation/screens/transaction_history_screen.dart';
import 'package:coinly/features/budgets/presentation/screens/budgets_screen.dart';
import 'package:coinly/features/settings/presentation/screens/settings_screen.dart';
import 'package:coinly/features/accounts/presentation/screens/manage_accounts_screen.dart';
import 'package:coinly/features/categories/presentation/screens/manage_categories_screen.dart';
import 'package:coinly/features/recurring/presentation/screens/recurring_screen.dart';
import 'package:coinly/features/sms_import/presentation/screens/sms_review_screen.dart';
import 'package:coinly/features/affordability/presentation/screens/affordability_screen.dart';
import 'package:coinly/features/settings/presentation/screens/planning_profile_screen.dart';
import 'package:coinly/features/goals/presentation/screens/goals_screen.dart';
import 'package:coinly/shared/widgets/app_bottom_nav.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider.notifier);
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: ref.watch(goRouterRefreshProvider),
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      if (auth.state.status == AuthStatus.loading) return null;
      if (auth.state.status == AuthStatus.unauthenticated && !isAuthRoute) {
        return '/auth/login';
      }
      if (auth.state.status == AuthStatus.authenticated && isAuthRoute) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/auth/signup',
        builder: (context, state) => const AuthScreen(isSignUp: true),
      ),
      GoRoute(
        path: '/affordability',
        builder: (context, state) => const AffordabilityScreen(),
      ),
      GoRoute(path: '/goals', builder: (context, state) => const GoalsScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppBottomNav(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (context, state) => const TransactionHistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/budgets',
                builder: (context, state) => const BudgetsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'accounts',
                    builder: (context, state) => const ManageAccountsScreen(),
                  ),
                  GoRoute(
                    path: 'categories',
                    builder: (context, state) => const ManageCategoriesScreen(),
                  ),
                  GoRoute(
                    path: 'recurring',
                    builder: (context, state) => const RecurringScreen(),
                  ),
                  GoRoute(
                    path: 'sms-import',
                    builder: (context, state) => const SmsReviewScreen(),
                  ),
                  GoRoute(
                    path: 'planning',
                    builder: (context, state) => const PlanningProfileScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
