// Manual Testing Checklist:
// [ ] Screen opens from Home → Recent Transactions → "See All"
// [ ] Transactions are grouped by date (Today, Yesterday, specific dates)
// [ ] Tapping a transaction opens the Transaction Detail sheet
// [ ] Date range filter chips work (This Month, Last Month, etc.)
// [ ] Type filter works (All, Income, Expense)
// [ ] Wallet filter works (All Wallets + individual wallets)
// [ ] Category filter works (All Categories + individual categories)
// [ ] Member filter shows for Head users only (All Members + individual members)
// [ ] Search box filters by note and category name
// [ ] Filter count badge shows correct number of active filters
// [ ] Clear all filters button resets to default state
// [ ] Infinite scroll / load more works for long lists
// [ ] Empty state shows when no transactions match filters
// MANUAL TEST CHECKLIST - TRANSACTION EXPORT
// 1. Open "All Transactions" as Head and Member.
// 2. Tap menu -> "Export data" -> "Export as CSV":
//    - Should show loading briefly then a SnackBar: "Exported to transactions_<household>_<timestamp>.csv" with an "Open" action.
//    - Tapping "Open" should open the CSV in a viewer app if available.
//    - "Share file" sheet should let you send via email/chat.
// 3. Tap "Export as Excel (.xlsx)":
//    - Same behavior but with .xlsx file.
//    - Open in a spreadsheet app; columns and rows match CSV export.
// 4. Apply filters/search on All Transactions and export:
//    - Only visible (filtered) transactions are included in both CSV and Excel.
// 5. Verify: "Import from CSV (beta)" still appears and works as before.
// 6. Verify: No crashes or UI glitches when exporting with zero transactions.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/actor_utils.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/enums/app_currency.dart';
import '../../../data/models/household_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/models/transaction_filter_state.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/file_share_service.dart';
import '../../providers/category_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/household_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/transaction_filter_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/transaction_detail_sheet.dart';

enum ExportFormat { csv, excel }

class TransactionsListScreen extends ConsumerStatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  ConsumerState<TransactionsListScreen> createState() =>
      _TransactionsListScreenState();
}

class _TransactionsListScreenState
    extends ConsumerState<TransactionsListScreen> {
  final _searchController = TextEditingController();
  bool _showFilters = false;
  List<TransactionModel> _latestVisibleTransactions = const [];
  final FileShareService _fileShareService = const FileShareService();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authUserProvider);
    final filterState = ref.watch(transactionFilterProvider);
    final settingsAsync = ref.watch(appSettingsProvider);
    final preferredCurrency = settingsAsync.valueOrNull?.currency ?? AppCurrency.usd;

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Transactions')),
        body: const Center(child: Text('Unable to load user information.')),
      ),
      data: (user) {
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Transactions')),
            body: const Center(child: Text('You must be signed in.')),
          );
        }

        final householdAsync = ref.watch(currentUserHouseholdProvider);
        final householdId = householdAsync.maybeWhen(
          data: (household) => household?.householdId ?? user.householdId ?? '',
          orElse: () => user.householdId ?? '',
        );

        // Get transactions based on user role
        final transactionsProvider = user.isHead
            ? householdTransactionsProvider(HouseholdTxParams(
                householdId: householdId,
                limit: 500, // Higher limit for full transactions list
              ))
            : userRecentTransactionsProvider(UserTransactionParams(
                userId: user.userId,
                householdId: householdId.isEmpty ? null : householdId,
                limit: 500,
              ));

        final transactionsAsync = ref.watch(transactionsProvider);

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            title: const Text('All Transactions'),
            actions: [
              // Filter button with badge
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () {
                      setState(() => _showFilters = !_showFilters);
                    },
                  ),
                  if (filterState.activeFilterCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${filterState.activeFilterCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'export') {
                    _onExportPressed(context);
                  } else if (value == 'import') {
                    _onImportPressed(context);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'export',
                    child: Text('Export data'),
                  ),
                  const PopupMenuItem(
                    value: 'import',
                    child: Text('Import from CSV (beta)'),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search transactions...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(transactionFilterProvider.notifier)
                                  .setSearchQuery('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    ref
                        .read(transactionFilterProvider.notifier)
                        .setSearchQuery(value);
                  },
                ),
              ),
              // Filters section (collapsible)
              if (_showFilters)
                _FiltersSection(
                  userId: user.userId,
                  householdId: householdId,
                  isHead: user.isHead,
                ),
              // Transactions list
              Expanded(
                child: transactionsAsync.when(
                  data: (transactions) {
                    final filtered = ref.watch(
                      filteredTransactionsProvider((
                        transactions: transactions,
                        filter: filterState,
                      )),
                    );
                    _latestVisibleTransactions = filtered;

                    if (filtered.isEmpty) {
                      return _EmptyState(
                        hasFilters: filterState.hasActiveFilters,
                        onClearFilters: () {
                          ref
                              .read(transactionFilterProvider.notifier)
                              .resetFilters();
                          _searchController.clear();
                        },
                      );
                    }

                    return _GroupedTransactionsList(
                      transactions: filtered,
                      currency: preferredCurrency,
                      onTransactionTap: (transaction) {
                        _showTransactionDetail(context, transaction);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Failed to load transactions',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            ref.invalidate(transactionsProvider);
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onExportPressed(BuildContext context) {
    final user = ref.read(authUserProvider).valueOrNull;
    final household = ref.read(currentUserHouseholdProvider).valueOrNull;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to export data.')),
      );
      return;
    }

    _showExportSheet(context, user, household);
  }

  void _onImportPressed(BuildContext context) {
    final user = ref.read(authUserProvider).valueOrNull;
    final household = ref.read(currentUserHouseholdProvider).valueOrNull;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to import data.')),
      );
      return;
    }

    _showImportSheet(context, user, household);
  }

  void _showExportSheet(
    BuildContext context,
    UserModel user,
    HouseholdModel? household,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Export data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Download visible transactions. CSV or Excel work with spreadsheets or for re-import.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Export as CSV'),
                subtitle: const Text('Includes all visible transactions'),
                onTap: () => _handleExport(
                  sheetContext,
                  user,
                  household,
                  ExportFormat.csv,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.table_view_outlined),
                title: const Text('Export as Excel (.xlsx)'),
                subtitle: const Text('Spreadsheet friendly'),
                onTap: () => _handleExport(
                  sheetContext,
                  user,
                  household,
                  ExportFormat.excel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleExport(
    BuildContext sheetContext,
    UserModel user,
    HouseholdModel? household,
    ExportFormat format,
  ) async {
    Navigator.of(sheetContext).pop(); // Close bottom sheet
    if (!mounted) return;

    if (_latestVisibleTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to export')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final exportService = ref.read(transactionExportServiceProvider);
      final currencyPreference = ref.read(appSettingsProvider).valueOrNull?.currency;
      final file = format == ExportFormat.csv
          ? await exportService.exportTransactionsToCsv(
              transactions: _latestVisibleTransactions,
              user: user,
              household: household,
              currencyPreference: currencyPreference,
            )
          : await exportService.exportTransactionsToExcel(
              transactions: _latestVisibleTransactions,
              user: user,
              household: household,
              currencyPreference: currencyPreference,
            );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss progress
      _showExportSuccess(file, format);
    } catch (e, st) {
      debugPrint('[EXPORT] Failed: $e\n$st');
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss progress
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  void _showExportSuccess(File file, ExportFormat format) {
    final fileName =
        file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : file.path;
    final mimeType = format == ExportFormat.csv
        ? 'text/csv'
        : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported to $fileName'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => _fileShareService.openFile(file),
        ),
      ),
    );

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(fileName),
              subtitle: Text(file.path),
            ),
            ListTile(
              leading: const Icon(Icons.file_open),
              title: const Text('Open file'),
              onTap: () {
                Navigator.of(ctx).pop();
                _fileShareService.openFile(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Share file'),
              onTap: () {
                Navigator.of(ctx).pop();
                _fileShareService.shareFile(
                  file,
                  subject: 'Transactions export',
                  text: 'Exported from the finance app',
                  mimeType: mimeType,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showImportSheet(
    BuildContext context,
    UserModel user,
    HouseholdModel? household,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Import from CSV (beta)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Import bank CSVs or a file exported from this app. Duplicates are skipped using date, amount, wallet, and note.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _performImport(sheetContext, user, household),
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Choose CSV file'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _performImport(
    BuildContext context,
    UserModel user,
    HouseholdModel? household,
  ) async {
    Navigator.of(context).pop(); // Close bottom sheet
    if (!mounted) return;
    showDialog(
      context: this.context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final importService = ref.read(transactionImportServiceProvider);
      final summary = await importService.importFromCsv(
        user: user,
        household: household,
      );

      if (!mounted) return;
      Navigator.of(this.context, rootNavigator: true).pop(); // Dismiss progress
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text(
            'Import complete: ${summary.createdCount} created, ${summary.duplicateCount} duplicates, ${summary.errorCount} errors out of ${summary.totalRows} rows.',
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('[IMPORT] Failed: $e\n$st');
      if (!mounted) return;
      Navigator.of(this.context, rootNavigator: true).pop(); // Dismiss progress
      final message =
          e.toString().contains('No file selected') ? 'Import cancelled' : 'Import failed: $e';
      ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showTransactionDetail(
      BuildContext context, TransactionModel transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => TransactionDetailSheet(
          transaction: transaction,
        ),
      ),
    );
  }
}

class _FiltersSection extends ConsumerWidget {
  final String userId;
  final String householdId;
  final bool isHead;

  const _FiltersSection({
    required this.userId,
    required this.householdId,
    required this.isHead,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(transactionFilterProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (filterState.hasActiveFilters)
                TextButton(
                  onPressed: () {
                    ref.read(transactionFilterProvider.notifier).resetFilters();
                  },
                  child: const Text('Clear All'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Date range filter
          _DateRangeFilter(),
          const SizedBox(height: 12),
          // Type filter
          _TypeFilter(),
          const SizedBox(height: 12),
          // Wallet filter
          _WalletFilter(userId: userId, householdId: householdId, isHead: isHead),
          const SizedBox(height: 12),
          // Category filter
          _CategoryFilter(),
          if (isHead) ...[
            const SizedBox(height: 12),
            // Member filter (only for heads)
            _MemberFilter(householdId: householdId),
          ],
        ],
      ),
    );
  }
}

class _DateRangeFilter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(transactionFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date Range',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DateRangeFilter.values.map((filter) {
            final isSelected = filterState.dateRangeFilter == filter;
            return ChoiceChip(
              label: Text(filter.displayName),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  if (filter == DateRangeFilter.custom) {
                    _showCustomDatePicker(context, ref);
                  } else {
                    ref
                        .read(transactionFilterProvider.notifier)
                        .setDateRangeFilter(filter);
                  }
                }
              },
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _showCustomDatePicker(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      ),
    );
    if (picked != null) {
      ref.read(transactionFilterProvider.notifier).setCustomDateRange(picked);
    }
  }
}

class _TypeFilter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(transactionFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Type',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: filterState.typeFilter == null,
              onSelected: (selected) {
                if (selected) {
                  ref.read(transactionFilterProvider.notifier).setTypeFilter(null);
                }
              },
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: filterState.typeFilter == null
                    ? Colors.white
                    : AppColors.textPrimary,
              ),
            ),
            ...TransactionType.values.map((type) {
              final isSelected = filterState.typeFilter == type;
              return ChoiceChip(
                label: Text(_getTypeLabel(type)),
                selected: isSelected,
                onSelected: (selected) {
                  ref
                      .read(transactionFilterProvider.notifier)
                      .setTypeFilter(selected ? type : null);
                },
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  String _getTypeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.transfer:
        return 'Transfer';
    }
  }
}

class _WalletFilter extends ConsumerWidget {
  final String userId;
  final String householdId;
  final bool isHead;

  const _WalletFilter({
    required this.userId,
    required this.householdId,
    required this.isHead,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(transactionFilterProvider);

    final walletParams = WalletVisibilityParams(
      userId: userId,
      householdId: householdId,
    );
    final walletProvider = isHead
        ? headWalletsProvider(HeadWalletParams(
            householdId: householdId,
            userId: userId,
          ))
        : memberWalletsProvider(walletParams);

    final walletsAsync = ref.watch(walletProvider);

    return walletsAsync.when(
      data: (wallets) {
        if (wallets.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Wallet',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All Wallets'),
                  selected: filterState.walletIdFilter == null,
                  onSelected: (selected) {
                    if (selected) {
                      ref
                          .read(transactionFilterProvider.notifier)
                          .setWalletFilter(null);
                    }
                  },
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: filterState.walletIdFilter == null
                        ? Colors.white
                        : AppColors.textPrimary,
                  ),
                ),
                ...wallets.map((wallet) {
                  final isSelected = filterState.walletIdFilter == wallet.walletId;
                  return ChoiceChip(
                    label: Text(wallet.name),
                    selected: isSelected,
                    onSelected: (selected) {
                      ref
                          .read(transactionFilterProvider.notifier)
                          .setWalletFilter(selected ? wallet.walletId : null);
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  );
                }),
              ],
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _CategoryFilter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(transactionFilterProvider);

    // Hardcoded categories for now - will be replaced with proper category provider
    final categories = [
      ('food', 'Food'),
      ('shopping', 'Shopping'),
      ('transport', 'Transport'),
      ('bills', 'Bills'),
      ('entertainment', 'Entertainment'),
      ('health', 'Health'),
      ('salary', 'Salary'),
      ('business', 'Business'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All Categories'),
              selected: filterState.categoryIdFilter == null,
              onSelected: (selected) {
                if (selected) {
                  ref
                      .read(transactionFilterProvider.notifier)
                      .setCategoryFilter(null);
                }
              },
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: filterState.categoryIdFilter == null
                    ? Colors.white
                    : AppColors.textPrimary,
              ),
            ),
            ...categories.map((category) {
              final isSelected = filterState.categoryIdFilter == category.$1;
              return ChoiceChip(
                label: Text(category.$2),
                selected: isSelected,
                onSelected: (selected) {
                  ref
                      .read(transactionFilterProvider.notifier)
                      .setCategoryFilter(selected ? category.$1 : null);
                },
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              );
            }),
          ],
        ),
      ],
    );
  }
}

class _MemberFilter extends ConsumerWidget {
  final String householdId;

  const _MemberFilter({required this.householdId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(transactionFilterProvider);
    final membersAsync = ref.watch(householdMembersProvider(householdId));

    return membersAsync.when(
      data: (members) {
        if (members.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Member',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All Members'),
                  selected: filterState.memberIdFilter == null,
                  onSelected: (selected) {
                    if (selected) {
                      ref
                          .read(transactionFilterProvider.notifier)
                          .setMemberFilter(null);
                    }
                  },
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: filterState.memberIdFilter == null
                        ? Colors.white
                        : AppColors.textPrimary,
                  ),
                ),
                ...members.map((member) {
                  final isSelected = filterState.memberIdFilter == member.userId;
                  return ChoiceChip(
                    label: Text('Member ${member.userId.substring(0, 8)}...'),
                    selected: isSelected,
                    onSelected: (selected) {
                      ref
                          .read(transactionFilterProvider.notifier)
                          .setMemberFilter(selected ? member.userId : null);
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  );
                }),
              ],
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _GroupedTransactionsList extends StatelessWidget {
  final List<TransactionModel> transactions;
  final AppCurrency currency;
  final Function(TransactionModel) onTransactionTap;

  const _GroupedTransactionsList({
    required this.transactions,
    required this.currency,
    required this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = _groupTransactionsByDate(transactions);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final group = grouped[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Text(
                group.header,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              ),
              ...group.transactions.map((transaction) {
                return _TransactionItem(
                  transaction: transaction,
                  currency: currency,
                  onTap: () => onTransactionTap(transaction),
                );
              }),
            if (index < grouped.length - 1) const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  List<_DateGroup> _groupTransactionsByDate(List<TransactionModel> transactions) {
    final groups = <_DateGroup>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    Map<String, List<TransactionModel>> dateMap = {};

    for (var transaction in transactions) {
      final date = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );

      String key;
      if (date == today) {
        key = 'Today';
      } else if (date == yesterday) {
        key = 'Yesterday';
      } else {
        key = DateFormat('MMM dd, yyyy').format(date);
      }

      dateMap.putIfAbsent(key, () => []).add(transaction);
    }

    // Sort groups by date (newest first)
    final sortedKeys = dateMap.keys.toList();
    for (var key in sortedKeys) {
      groups.add(_DateGroup(
        header: key,
        transactions: dateMap[key]!,
      ));
    }

    return groups;
  }
}

class _DateGroup {
  final String header;
  final List<TransactionModel> transactions;

  _DateGroup({
    required this.header,
    required this.transactions,
  });
}

class _TransactionItem extends ConsumerWidget {
  final TransactionModel transaction;
  final VoidCallback onTap;
  final AppCurrency currency;

  const _TransactionItem({
    required this.transaction,
    required this.onTap,
    required this.currency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = transaction.type == TransactionType.expense;
    final color = isExpense ? AppColors.error : AppColors.success;
    final formatted = MoneyFormatter.format(
      transaction.amount,
      currency: currency,
    );
    final amountLabel = switch (transaction.type) {
      TransactionType.expense => '-$formatted',
      TransactionType.income => '+$formatted',
      TransactionType.transfer => formatted,
    };

    final nameMap = ref.watch(
      categoryNameMapProvider(
        CategoryNameMapParams(
          userId: transaction.userId,
          householdId: transaction.householdId,
        ),
      ),
    );
    final resolvedCategory = (transaction.categoryName != null && transaction.categoryName!.isNotEmpty)
        ? transaction.categoryName!
        : nameMap[transaction.categoryId] ?? 'Unknown category';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            isExpense ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
          ),
        ),
        title: Text(
          transaction.note.isNotEmpty ? transaction.note : resolvedCategory,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Row(
          children: [
            Text(
              transaction.actorDisplayName != null
                  ? formatActorLabel(
                      transaction.actorDisplayName!,
                      transaction.actorRole ?? 'member',
                    )
                  : DateFormat('hh:mm a').format(transaction.date),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            if (transaction.status != TransactionStatus.approved) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(transaction.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  transaction.status.displayName,
                  style: TextStyle(
                    fontSize: 10,
                    color: _getStatusColor(transaction.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Text(
          amountLabel,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.approved:
        return AppColors.success;
      case TransactionStatus.pending:
        return AppColors.warning;
      case TransactionStatus.rejected:
        return AppColors.error;
    }
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClearFilters;

  const _EmptyState({
    required this.hasFilters,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? Icons.search_off : Icons.receipt_long,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No transactions found' : 'No transactions yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try adjusting your filters to see more results.'
                  : 'Add your first transaction to get started.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onClearFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Clear All Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
