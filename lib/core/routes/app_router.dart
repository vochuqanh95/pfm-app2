import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/sign_up_screen.dart';
import '../../presentation/screens/auth/two_factor_screen.dart';
import '../../presentation/screens/auth/forgot_password_screen.dart';
import '../../presentation/screens/onboarding/onboarding_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/wallet/wallet_list_screen.dart';
import '../../presentation/screens/goals/goals_list_screen.dart';
import '../../presentation/screens/reports/reports_screen.dart';
import '../../presentation/screens/budget/budget_list_screen.dart';
import '../../presentation/screens/budget/budget_detail_screen.dart';
import '../../presentation/screens/budget/add_budget_screen.dart';
import '../../presentation/screens/bill/bills_overview_screen.dart';
import '../../presentation/screens/bill/bill_detail_screen.dart';
import '../../presentation/screens/bill/add_edit_bill_screen.dart';
import '../../presentation/screens/debt/debt_list_screen.dart';
import '../../presentation/screens/debt/debt_detail_screen.dart';
import '../../presentation/screens/debt/add_debt_screen.dart';
import '../../presentation/screens/debt/edit_debt_screen.dart';
import '../../presentation/screens/transaction/edit_transaction_screen.dart';
import '../../presentation/screens/notification/notification_center_screen.dart';
import '../../presentation/screens/approval/approval_list_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/household/member_management_screen.dart';
import '../../presentation/screens/household/create_household_screen.dart';
import '../../presentation/screens/household/join_household_screen.dart';
import '../../presentation/screens/transaction/add_transaction_screen.dart';
import '../../presentation/screens/transaction/transactions_list_screen.dart';
import '../../presentation/screens/recurring/recurring_rules_screen.dart';
import '../../presentation/screens/wallet/add_edit_wallet_screen.dart';
import '../../data/models/wallet_model.dart';
import '../../presentation/screens/goals/add_goal_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final userProfile = ref.watch(authUserProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final location = state.uri.path.isEmpty ? '/splash' : state.uri.path;
      final unauthenticatedRoutes = {
        '/login',
        '/sign-up',
        '/two-factor',
        '/onboarding',
        '/forgot-password'
      };
      final redirectToHomeRoutes = {
        '/login',
        '/sign-up',
        '/splash',
        '/two-factor',
        '/onboarding'
      };
      final isLoading = authState.isLoading || userProfile.isLoading;

      if (isLoading) {
        return location == '/splash' ? null : '/splash';
      }

      if (authState.hasError || userProfile.hasError) {
        return location == '/login' ? null : '/login';
      }

      final firebaseUser = authState.valueOrNull;
      final user = userProfile.valueOrNull;

      if (firebaseUser == null || user == null) {
        if (unauthenticatedRoutes.contains(location)) {
          return null;
        }
        return '/login';
      }

      final hasHousehold = (user.householdId?.isNotEmpty ?? false);
      final isHead = user.isHead;
      final requiresHeadOnboarding = isHead && !hasHousehold;
      final desiredHome = isHead ? '/home' : '/member-home';

      if (requiresHeadOnboarding && location != '/create-household') {
        return '/create-household';
      }

      if (!requiresHeadOnboarding && location == '/create-household') {
        return desiredHome;
      }

      if (location == '/join-household') {
        final canAccessJoin = user.isMember && !hasHousehold;
        if (!canAccessJoin) {
          return desiredHome;
        }
        return null;
      }

      // Allow /two-factor for authenticated users with query params (2FA verification in progress)
      if (location == '/two-factor' &&
          state.uri.queryParameters.containsKey('userId')) {
        return null;
      }

      if (redirectToHomeRoutes.contains(location)) {
        return desiredHome;
      }

      if (!isHead && location == '/home') {
        return '/member-home';
      }

      if (isHead && location == '/member-home') {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/member-home',
        name: 'member-home',
        builder: (context, state) => const HomeScreen(isMemberView: true),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/wallets',
        name: 'wallets',
        builder: (context, state) => const WalletListScreen(),
      ),
      GoRoute(
        path: '/wallet/add',
        name: 'wallet-add',
        builder: (context, state) => const AddEditWalletScreen(),
      ),
      GoRoute(
        path: '/wallet/edit',
        name: 'wallet-edit',
        builder: (context, state) {
          final wallet =
              state.extra is WalletModel ? state.extra as WalletModel : null;
          return AddEditWalletScreen(wallet: wallet);
        },
      ),
      GoRoute(
        path: '/goals',
        name: 'goals',
        builder: (context, state) => const GoalsListScreen(),
      ),
      GoRoute(
        path: '/reports',
        name: 'reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/goal/add',
        name: 'goal-add',
        builder: (context, state) => const AddGoalScreen(),
      ),
      // Auth routes
      GoRoute(
        path: '/sign-up',
        name: 'sign-up',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/two-factor',
        name: 'two-factor',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          final userId = state.uri.queryParameters['userId'] ?? '';
          return TwoFactorScreen(email: email, userId: userId);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      // Budget routes
      GoRoute(
        path: '/budgets',
        name: 'budgets',
        builder: (context, state) => const BudgetListScreen(),
      ),
      GoRoute(
        path: '/budget-detail/:id',
        name: 'budget-detail',
        builder: (context, state) {
          final budgetId = state.pathParameters['id']!;
          return BudgetDetailScreen(budgetId: budgetId);
        },
      ),
      GoRoute(
        path: '/add-budget',
        name: 'add-budget',
        builder: (context, state) => const AddBudgetScreen(),
      ),
      // Bill routes
      GoRoute(
        path: '/bills',
        name: 'bills',
        builder: (context, state) => const BillsOverviewScreen(),
      ),
      GoRoute(
        path: '/bill/add',
        name: 'bill-add',
        builder: (context, state) => const AddEditBillScreen(),
      ),
      GoRoute(
        path: '/bill/edit/:id',
        name: 'bill-edit',
        builder: (context, state) {
          final billId = state.pathParameters['id']!;
          // TODO: Load bill and pass to screen
          return const AddEditBillScreen();
        },
      ),
      GoRoute(
        path: '/bill-detail/:id',
        name: 'bill-detail',
        builder: (context, state) {
          final billId = state.pathParameters['id']!;
          return BillDetailScreen(billId: billId);
        },
      ),
      // Debt routes
      GoRoute(
        path: '/debts',
        name: 'debts',
        builder: (context, state) => const DebtListScreen(),
      ),
      GoRoute(
        path: '/debt-detail/:id',
        name: 'debt-detail',
        builder: (context, state) {
          final debtId = state.pathParameters['id']!;
          return DebtDetailScreen(debtId: debtId);
        },
      ),
      GoRoute(
        path: '/add-debt',
        name: 'add-debt',
        builder: (context, state) => const AddDebtScreen(),
      ),
      GoRoute(
        path: '/debt-edit/:id',
        name: 'edit-debt',
        builder: (context, state) {
          final debtId = state.pathParameters['id']!;
          return EditDebtScreen(debtId: debtId);
        },
      ),
      // Notification & Approval routes
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationCenterScreen(),
      ),
      GoRoute(
        path: '/approvals',
        name: 'approvals',
        builder: (context, state) => const ApprovalListScreen(),
      ),
      // Settings & Member Management routes
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/member-management',
        name: 'member-management',
        builder: (context, state) => const MemberManagementScreen(),
      ),
      GoRoute(
        path: '/create-household',
        name: 'create-household',
        builder: (context, state) => const CreateHouseholdScreen(),
      ),
      GoRoute(
        path: '/join-household',
        name: 'join-household',
        builder: (context, state) => const JoinHouseholdScreen(),
      ),
      GoRoute(
        path: '/add-transaction',
        name: 'add-transaction',
        builder: (context, state) => const AddTransactionScreen(),
      ),
      GoRoute(
        path: '/transaction/:id/edit',
        name: 'edit-transaction',
        builder: (context, state) {
          final transactionId = state.pathParameters['id']!;
          return EditTransactionScreen(transactionId: transactionId);
        },
      ),
      GoRoute(
        path: '/transactions',
        name: 'transactions',
        builder: (context, state) => const TransactionsListScreen(),
      ),
      GoRoute(
        path: '/recurring-transactions',
        name: 'recurring-transactions',
        builder: (context, state) => const RecurringRulesScreen(),
      ),
    ],
  );
});
