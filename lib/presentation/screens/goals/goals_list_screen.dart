import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/goal_model.dart';
import '../../../data/models/wallet_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/household_provider.dart';
import '../../widgets/bottom_nav_bar.dart';

class GoalsListScreen extends ConsumerWidget {
  const GoalsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(body: Center(child: Text('Unable to load goals'))),
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text('Please sign in.')));
        }

        final familyGoalsStream = ref.watch(familyGoalsProvider);
        final memberGoalsStream = ref.watch(myGoalsProvider);

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            title: const Text('Goals'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => context.push('/goal/add'),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GoalsSection(
                  title: user.isHead ? 'Family goals' : 'Family goals',
                  goalsAsync: familyGoalsStream,
                  onRetry: () => ref.refresh(familyGoalsProvider),
                  emptyText: 'No family goals yet',
                ),
                const SizedBox(height: 16),
                _GoalsSection(
                  title: user.isHead ? 'My goals' : 'My goals',
                  goalsAsync: memberGoalsStream,
                  onRetry: () => ref.refresh(myGoalsProvider),
                  emptyText: 'No personal goals yet',
                ),
              ],
            ),
          ),
          bottomNavigationBar: const BottomNavBar(currentIndex: 2),
        );
      },
    );
  }
}

class _GoalsSection extends StatelessWidget {
  final String title;
  final AsyncValue<List<GoalModel>> goalsAsync;
  final String emptyText;
  final VoidCallback onRetry;

  const _GoalsSection({
    required this.title,
    required this.goalsAsync,
    required this.emptyText,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        goalsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: TextButton(
              onPressed: onRetry,
              child: const Text('Unable to load goals. Retry'),
            ),
          ),
          data: (goals) {
            if (goals.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  emptyText,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: goals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) => _GoalCard(goal: goals[index]),
            );
          },
        ),
      ],
    );
  }
}

class _GoalCard extends ConsumerWidget {
  final GoalModel goal;

  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = goal.progress.clamp(0, 100);
    final deadlineLabel = goal.deadline != null
        ? 'Due ${goal.deadline!.toLocal().toString().split(' ').first}'
        : 'No deadline';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    if (goal.assignedUserDisplayName != null && goal.scope == 'personal')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Assigned to: ${goal.assignedUserDisplayName}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                'USD ${goal.savedAmount.toStringAsFixed(0)} / ${goal.targetAmount.toStringAsFixed(0)}',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 80 ? AppColors.success : AppColors.secondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${progress.toStringAsFixed(1)}% complete',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              Text(
                deadlineLabel,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          if (!goal.isCompleted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showContributionDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Contribution'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showContributionDialog(BuildContext context, WidgetRef ref) async {
    // Get current user and household
    final userAsync = ref.read(authUserProvider);
    final user = userAsync.value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found')),
      );
      return;
    }

    final householdAsync = ref.read(currentUserHouseholdProvider);
    final householdId = householdAsync.maybeWhen(
      data: (h) => h?.householdId ?? user.householdId ?? '',
      orElse: () => user.householdId ?? '',
    );

    // Determine which wallets to show based on goal scope and user role
    List<WalletModel> availableWallets = [];
    if (goal.scope == 'family') {
      // Family goal - show household wallets
      if (user.isHead) {
        // Head sees all household wallets
        final walletsProvider = headWalletsProvider(HeadWalletParams(
          householdId: householdId,
          userId: user.userId,
        ));
        final walletsAsync = await ref.read(walletsProvider.future);
        availableWallets = walletsAsync.where((w) =>
          w.householdId == householdId && w.scope == WalletScope.householdShared
        ).toList();
      } else {
        // Member sees household shared wallets only
        final walletsProvider = memberWalletsProvider(WalletVisibilityParams(
          userId: user.userId,
          householdId: householdId,
        ));
        final walletsAsync = await ref.read(walletsProvider.future);
        availableWallets = walletsAsync.where((w) =>
          w.scope == WalletScope.householdShared
        ).toList();
      }
    } else {
      // Personal goal - show only personal wallets
      final walletsProvider = memberWalletsProvider(WalletVisibilityParams(
        userId: user.userId,
        householdId: householdId,
      ));
      final walletsAsync = await ref.read(walletsProvider.future);
      availableWallets = walletsAsync.where((w) =>
        w.scope == WalletScope.personal && w.userId == user.userId
      ).toList();
    }

    if (availableWallets.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No wallets available. Please create a wallet first.')),
        );
      }
      return;
    }

    // Show dialog with wallet picker
    final amountController = TextEditingController();
    WalletModel? selectedWallet = availableWallets.first;

    if (!context.mounted) return;
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Contribution'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$ ',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<WalletModel>(
                initialValue: selectedWallet,
                decoration: const InputDecoration(
                  labelText: 'From Wallet',
                  border: OutlineInputBorder(),
                ),
                items: availableWallets.map((wallet) {
                  return DropdownMenuItem(
                    value: wallet,
                    child: Text(
                      '${wallet.name} (\$${wallet.balance.toStringAsFixed(2)})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (wallet) {
                  setState(() {
                    selectedWallet = wallet;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount')),
                  );
                  return;
                }
                if (selectedWallet == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a wallet')),
                  );
                  return;
                }
                Navigator.pop(dialogContext, {
                  'amount': amount,
                  'wallet': selectedWallet,
                });
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result['amount'] != null && result['wallet'] != null) {
      final amount = result['amount'] as double;
      final wallet = result['wallet'] as WalletModel;

      try {
        print('[UI] Add contribution button pressed: amount=\$${amount.toStringAsFixed(2)}, wallet=${wallet.name}');
        final notifier = ref.read(goalNotifierProvider.notifier);
        await notifier.addContribution(
          goalId: goal.goalId,
          amount: amount,
          wallet: wallet,
          user: user,
        );

        print('[UI] ✓ Contribution successful, showing success message');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Added \$${amount.toStringAsFixed(2)} to ${goal.name} from ${wallet.name}'),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        print('[UI] ❌ Contribution failed: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add contribution: $e'),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }
}
