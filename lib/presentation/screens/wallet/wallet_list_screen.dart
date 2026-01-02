import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance_management/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/enums/app_currency.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../data/models/wallet_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/household_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/bottom_nav_bar.dart';

class WalletListScreen extends ConsumerWidget {
  const WalletListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authUserProvider);
    final householdAsync = ref.watch(currentUserHouseholdProvider);
    final settingsAsync = ref.watch(appSettingsProvider);
    final currency = settingsAsync.valueOrNull?.currency ?? AppCurrency.usd;
    final sharedLabel = AppLocalizations.of(context)?.sharedLabel ?? 'Shared';

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => const Scaffold(
        body: Center(child: Text('Unable to load wallets')),
      ),
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text('Please sign in.')));
        }

        final householdId = householdAsync.maybeWhen(
          data: (household) => household?.householdId ?? user.householdId ?? '',
          orElse: () => user.householdId ?? '',
        );

        final walletsProvider = user.isHead
            ? headWalletsProvider(
                HeadWalletParams(householdId: householdId, userId: user.userId),
              )
            : memberWalletsProvider(
                WalletVisibilityParams(
                  userId: user.userId,
                  householdId: householdId,
                ),
              );
        final walletsAsync = ref.watch(walletsProvider);

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            title: const Text('Wallets'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => context.push('/wallet/add'),
              ),
            ],
          ),
          body: walletsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _WalletError(
              onRetry: () => ref.refresh(walletsProvider),
            ),
            data: (wallets) {
              if (wallets.isEmpty) {
                return _WalletEmpty(
                  onCreate: () => context.push('/wallet/add'),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: wallets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final wallet = wallets[index];
                  return _WalletTile(
                    wallet: wallet,
                    currency: currency,
                    sharedLabel: sharedLabel,
                    canArchive: user.isHead,
                    onArchive: user.isHead
                        ? () => _confirmArchive(context, ref, wallet)
                        : null,
                    onTap: () => context.push('/wallet/edit', extra: wallet),
                  );
                },
              );
            },
          ),
          bottomNavigationBar: const BottomNavBar(currentIndex: 1),
        );
      },
    );
  }

  Future<void> _confirmArchive(
    BuildContext context,
    WidgetRef ref,
    WalletModel wallet,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete wallet'),
        content: const Text('This will archive the wallet. Transactions remain for history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    debugPrint('[WALLET_FIX] Archiving wallet id=${wallet.walletId} name=${wallet.name}');
    try {
      await ref.read(walletRepositoryProvider).archiveWallet(wallet.walletId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallet archived')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to archive wallet: $e')),
        );
      }
    }
  }
}

class _WalletTile extends StatelessWidget {
  final WalletModel wallet;
  final VoidCallback onTap;
  final AppCurrency currency;
  final String sharedLabel;
  final bool canArchive;
  final VoidCallback? onArchive;

  const _WalletTile({
    required this.wallet,
    required this.onTap,
    required this.currency,
    required this.sharedLabel,
    this.canArchive = false,
    this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final isShared = wallet.scope == WalletScope.householdShared;
    final typeLabel = _typeLabel(wallet.type);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_typeIcon(wallet.type), color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          wallet.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (canArchive)
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'archive' && onArchive != null) {
                              onArchive!();
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'archive',
                              child: Text('Delete wallet'),
                            ),
                          ],
                        ),
                      if (isShared)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            sharedLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    MoneyFormatter.format(wallet.balance, currency: currency),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(WalletType type) {
    switch (type) {
      case WalletType.bank:
        return Icons.account_balance;
      case WalletType.card:
        return Icons.credit_card;
      case WalletType.ewallet:
        return Icons.account_balance_wallet;
      case WalletType.cash:
      default:
        return Icons.payments;
    }
  }

  String _typeLabel(WalletType type) {
    switch (type) {
      case WalletType.bank:
        return 'Bank Account';
      case WalletType.card:
        return 'Card';
      case WalletType.ewallet:
        return 'E-Wallet';
      case WalletType.cash:
      default:
        return 'Cash';
    }
  }
}

class _WalletEmpty extends StatelessWidget {
  final VoidCallback onCreate;

  const _WalletEmpty({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppColors.primary),
            const SizedBox(height: 12),
            const Text(
              'No wallets yet',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              'Create a wallet to track your balances.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onCreate,
              child: const Text('Create First Wallet'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletError extends StatelessWidget {
  final VoidCallback onRetry;

  const _WalletError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 8),
            const Text('Unable to load wallets'),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
