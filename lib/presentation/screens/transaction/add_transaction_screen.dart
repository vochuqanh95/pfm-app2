import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../../core/theme/app_colors.dart';
import '../../../core/enums/app_currency.dart';
import '../../../core/utils/actor_utils.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/wallet_model.dart';
import '../../../data/models/recurring_rule_model.dart';
import '../../../data/repositories/recurring_rule_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/household_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/wallet_provider.dart';
import '../category/add_category_bottom_sheet.dart';

// MANUAL TEST CHECKLIST (Transactions & Categories)
// 1) Create EXPENSE $50 from wallet A with built-in category -> one doc, wallet A -$50, Recent shows once.
// 2) Create INCOME $100 to wallet A -> one doc, wallet A +$100, Recent shows once.
// 3) Add custom EXPENSE category -> appears immediately in picker and can be used for a transaction.
// 4) Edit amount 50 -> 80 (same wallet/type) -> wallet adjusts by +30 only once; no duplicate docs.
// 5) Edit note/category only -> wallet balance unchanged.
// 6) Login/logout or switch household -> Recent Transactions auto-load without tapping Reload.
// 7) FAB still opens Add Transaction; Debts quick action remains the only home tile.

class AddTransactionScreen extends ConsumerStatefulWidget {
  final TransactionType initialType;
  final TransactionModel? existingTransaction;

  const AddTransactionScreen({
    super.key,
    this.initialType = TransactionType.expense,
    this.existingTransaction,
  });

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _noteController = TextEditingController();
  final _imagePicker = ImagePicker();
  TransactionType _type = TransactionType.expense;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _amountText = '0';
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  String? _selectedWalletId;
  bool _isSaving = false;
  XFile? _selectedReceiptImage;
  Frequency? _selectedRecurringFrequency; // null = no recurrence
  bool get _isEdit => widget.existingTransaction != null;

  @override
  void initState() {
    super.initState();
    _type = widget.existingTransaction?.type ?? widget.initialType;
    final existing = widget.existingTransaction;
    if (existing != null) {
      _amountText = existing.amount.toStringAsFixed(2);
      _noteController.text = existing.note;
      _selectedCategoryId = existing.categoryId;
      _selectedCategoryName = existing.categoryName ?? existing.categoryId;
      _selectedWalletId = existing.walletId;
      _selectedDate = existing.date;
      _selectedTime = TimeOfDay.fromDateTime(existing.date);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authUserProvider);
    final householdAsync = ref.watch(currentUserHouseholdProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => const Scaffold(
        body: Center(child: Text('Unable to load your account.')),
      ),
      data: (user) {
        if (user == null) {
          return const Scaffold(
              body: Center(child: Text('You must be signed in.')));
        }

        final householdId = householdAsync.maybeWhen(
          data: (household) => household?.householdId ?? user.householdId ?? '',
          orElse: () => user.householdId ?? '',
        );

        final walletParams = WalletVisibilityParams(
          userId: user.userId,
          householdId: householdId,
        );
        final walletProvider = user.isHead
            ? headWalletsProvider(
                HeadWalletParams(
                  householdId: householdId,
                  userId: user.userId,
                ),
              )
            : memberWalletsProvider(walletParams);
        final walletAsync = ref.watch(walletProvider);
        final availableWallets = walletAsync.asData?.value ?? const <WalletModel>[];
        final showWalletEmptyState = walletAsync.maybeWhen(
          data: (wallets) => wallets.isEmpty,
          orElse: () => false,
        );

        if (_selectedWalletId == null && availableWallets.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(
                  () => _selectedWalletId = availableWallets.first.walletId);
            }
          });
        }

        final categoryHouseholdId =
            householdId.isEmpty ? null : householdId;
        final expenseCategoriesAsync = ref.watch(
          categoriesStreamProvider(
            CategoryQueryParams(
              type: CategoryType.expense,
              userId: user.userId,
              householdId: categoryHouseholdId,
            ),
          ),
        );
        final incomeCategoriesAsync = ref.watch(
          categoriesStreamProvider(
            CategoryQueryParams(
              type: CategoryType.income,
              userId: user.userId,
              householdId: categoryHouseholdId,
            ),
          ),
        );

        final expenseUi =
            _mapCategories(expenseCategoriesAsync.value ?? const <CategoryModel>[]);
        final incomeUi =
            _mapCategories(incomeCategoriesAsync.value ?? const <CategoryModel>[]);
        final currentCategories =
            _type == TransactionType.expense ? expenseUi : incomeUi;
        final categoriesWithPlaceholder = _ensureSelectedCategoryPresent(
          currentCategories,
          _selectedCategoryId,
          _type,
        );

        if (_selectedCategoryId == null && categoriesWithPlaceholder.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedCategoryId = categoriesWithPlaceholder.first.id;
                _selectedCategoryName = categoriesWithPlaceholder.first.name;
              });
            }
          });
        }

        final selectedWallet = _resolveSelectedWallet(availableWallets);
        final selectedCategory = categoriesWithPlaceholder.firstWhere(
          (cat) => cat.id == _selectedCategoryId,
          orElse: () => categoriesWithPlaceholder.isNotEmpty
              ? categoriesWithPlaceholder.first
              : _fallbackCategoryLocal(_type),
        );

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            title: const Text('Add Transaction'),
          ),
          body: SafeArea(
            child: Column(
              children: [
                _HeaderCard(
                  category: selectedCategory,
                  amountText: _amountText,
                  onCategoryTap: () => _showCategorySheet(
                    selectedType: _type,
                    user: user,
                    householdId: householdId,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _TypeSelector(
                          selected: _type,
                          onChanged: (type) {
                            if (_isEdit || type == TransactionType.transfer) return;
                            setState(() {
                              _type = type;
                              _selectedCategoryId = null;
                              _selectedCategoryName = null;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        _FieldTile(
                          icon: Icons.calendar_today,
                          label: 'Date',
                          value:
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                            }
                          },
                        ),
                        _FieldTile(
                          icon: Icons.access_time,
                          label: 'Time',
                          value: _selectedTime.format(context),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _selectedTime,
                            );
                            if (picked != null) {
                              setState(() => _selectedTime = picked);
                            }
                          },
                        ),
                        if (walletAsync.hasError)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _WalletInfoBanner(
                              icon: Icons.error_outline,
                              message: 'Unable to load wallets. Please try again.',
                              actionLabel: 'Retry',
                              onAction: () => ref.refresh(walletProvider),
                            ),
                          )
                        else if (showWalletEmptyState)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: _WalletInfoBanner(
                              icon: Icons.info_outline,
                              message: 'No wallet available. Please create a wallet first.',
                            ),
                          ),
                        _FieldTile(
                          icon: Icons.account_balance_wallet,
                          label: 'Wallet',
                          value: walletAsync.isLoading
                              ? 'Loading wallets...'
                              : selectedWallet?.name ??
                                  (showWalletEmptyState ? 'No wallet available' : 'Select wallet'),
                          onTap: _isEdit
                              ? null
                              : availableWallets.isEmpty
                                  ? _showNoWalletSheet
                                  : () => _showWalletPicker(availableWallets),
                        ),
                        _ReceiptAttachmentTile(
                          selectedImage: _selectedReceiptImage,
                          onTap: _showReceiptOptions,
                        ),
                        _NoteField(controller: _noteController),
                        const SizedBox(height: 16),
                        _RecurringSelector(
                          selectedFrequency: _selectedRecurringFrequency,
                          onChanged: (frequency) {
                            setState(() => _selectedRecurringFrequency = frequency);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                _Keypad(
                  onTap: _onKeyTap,
                  onBackspace: _handleBackspace,
                  onSubmit: _isSaving
                      ? null
                      : () => _saveTransaction(
                            user: user,
                            wallets: availableWallets,
                            householdId: householdId.isEmpty ? null : householdId,
                          ),
                  isSaving: _isSaving,
                  isEdit: _isEdit,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onKeyTap(String value) {
    setState(() {
      if (_amountText == '0' && value != '.') {
        _amountText = value;
        return;
      }
      if (value == '.' && _amountText.contains('.')) return;
      _amountText += value;
    });
  }

  void _handleBackspace() {
    if (_amountText.isEmpty) return;
    setState(() {
      final next = _amountText.substring(0, _amountText.length - 1);
      _amountText = next.isEmpty ? '0' : next;
    });
  }

  void _showCategorySheet({
    required TransactionType selectedType,
    required UserModel user,
    required String householdId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _CategorySheet(
          userId: user.userId,
          householdId: householdId.isEmpty ? null : householdId,
          selectedCategoryId: _selectedCategoryId,
          initialType: selectedType == TransactionType.expense
              ? CategoryType.expense
              : CategoryType.income,
          onSelect: (category) {
            setState(() {
              _selectedCategoryId = category.id;
              _selectedCategoryName = category.name;
              _type = category.type;
            });
            debugPrint(
                '[CATEGORY_FIX] Selected category id=${category.id} name=${category.name} type=${category.type.name}');
            Navigator.pop(context);
          },
          onAddCategory: (type) =>
              _handleAddCategory(type, user, householdId),
          onArchive: (category) => _handleArchiveCategory(category),
        );
      },
    );
  }

  Future<void> _handleAddCategory(
    CategoryType type,
    UserModel user,
    String householdId,
  ) async {
    final created = await showModalBottomSheet<CategoryModel>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddCategoryBottomSheet(
        type: type,
        userId: user.userId,
        householdId: householdId.isEmpty ? null : householdId,
        canCreateHouseholdCategory: user.isHead && householdId.isNotEmpty,
      ),
    );

    if (created != null && mounted) {
      setState(() {
        _type = created.type == CategoryType.expense
            ? TransactionType.expense
            : TransactionType.income;
        _selectedCategoryId = created.categoryId;
        _selectedCategoryName = created.name;
      });
      debugPrint(
          '[CATEGORY_FIX] Created and selected category id=${created.categoryId} name=${created.name}');
      // Auto-select and close picker if it's open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _handleArchiveCategory(_UiCategory category) async {
    if (category.isBuiltIn) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: const Text(
            'This hides the category from future transactions. Existing transactions keep their old category.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    debugPrint(
        '[CATEGORY_UI] Long-pressed category ${category.id}, scope=${category.model.scope.name}');

    try {
      await ref.read(categoryRepositoryProvider).archiveCategory(category.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category deleted')),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        final friendly = e.code == 'permission-denied'
            ? 'You do not have permission to delete this category.'
            : 'Failed to delete category: ${e.message ?? e.code}';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendly)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to delete category: $e')));
      }
    }
  }

  List<_UiCategory> _mapCategories(List<CategoryModel> categories) {
    return _mapCategoriesLocal(categories);
  }

  List<_UiCategory> _ensureSelectedCategoryPresent(
    List<_UiCategory> categories,
    String? selectedId,
    TransactionType type,
  ) {
    if (categories.isEmpty) {
      if (selectedId == null) return categories;
      return [_fallbackCategoryLocal(type, id: selectedId)];
    }
    final exists =
        selectedId != null && categories.any((c) => c.id == selectedId);
    if (exists || selectedId == null) return categories;
    return [
      ...categories,
      _fallbackCategoryLocal(type, id: selectedId),
    ];
  }

  void _showWalletPicker(List<WalletModel> wallets) {
    if (wallets.isEmpty) {
      _showNoWalletSheet();
      return;
    }
    final currency = ref.read(appSettingsProvider).valueOrNull?.currency ?? AppCurrency.usd;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: wallets
              .map(
                (wallet) => ListTile(
                  leading: const Icon(Icons.account_balance_wallet),
                  title: Text(wallet.name),
                  subtitle: Text(
                      MoneyFormatter.format(wallet.balance, currency: currency)),
                  onTap: () {
                    setState(() => _selectedWalletId = wallet.walletId);
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _showNoWalletSheet() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text(
                'No wallet yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a wallet from the Wallets tab before recording transactions.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    if (!mounted) return;
                    context.go('/wallets');
                  },
                  child: const Text('Go to Wallets'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReceiptOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickReceipt(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickReceipt(ImageSource.gallery);
              },
            ),
            if (_selectedReceiptImage != null)
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.error),
                title: const Text('Remove Receipt', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedReceiptImage = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedReceiptImage = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<String?> _uploadReceiptToStorage(String userId, String transactionId) async {
    if (_selectedReceiptImage == null) return null;

    try {
      final file = File(_selectedReceiptImage!.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('receipts')
          .child(userId)
          .child('$transactionId.jpg');

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload receipt: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _saveTransaction({
    required UserModel user,
    required List<WalletModel> wallets,
    String? householdId,
  }) async {
    final wallet = _resolveSelectedWallet(wallets);
    if (wallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a wallet')),
      );
      return;
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    final amount = double.tryParse(_amountText) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than 0')),
      );
      return;
    }

    final selectedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final categoryName = _selectedCategoryName ?? _selectedCategoryId ?? 'Category';

    final resolvedHouseholdId = wallet.householdId?.isNotEmpty == true
        ? wallet.householdId
        : ((householdId?.isNotEmpty ?? false)
            ? householdId
            : (user.householdId?.isNotEmpty == true ? user.householdId : null));

    setState(() => _isSaving = true);

    try {
      // Edit flow
      if (_isEdit) {
        final existing = widget.existingTransaction!;
        if (existing.type == TransactionType.transfer) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Editing transfers is not supported yet'),
            ),
          );
          return;
        }

        final updatedTx = existing.copyWith(
          amount: amount,
          note: _noteController.text.trim(),
          categoryId: _selectedCategoryId!,
          categoryName: categoryName,
          date: selectedDateTime,
          updatedAt: DateTime.now(),
        );

        debugPrint(
            '[TXN_FIX] Saving edited txn id=${existing.transactionId} category_id=${_selectedCategoryId} category_name=$categoryName amount=$amount');
        await ref.read(transactionServiceProvider).updateTransaction(updatedTx);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction updated')),
          );
          context.pop();
        }
        return;
      }

      // Build actor info from current user
      final actor = buildActorInfo(user);
      final transactionService = ref.read(transactionServiceProvider);
      final transactionRepository = ref.read(transactionRepositoryProvider);

      debugPrint(
          '[TXN_FIX] Saving txn with category_id=$_selectedCategoryId category_name=$categoryName amount=$amount wallet=${wallet.walletId}');
      // Create temporary transaction without receipt URL
      final tempTransaction = TransactionModel(
        transactionId: '',
        userId: user.userId,
        householdId: resolvedHouseholdId,
        categoryId: _selectedCategoryId!,
        categoryName: categoryName,
        categoryType: _type.name,
        walletId: wallet.walletId,
        amount: amount,
        currency: wallet.currency,
        type: _type,
        note: _noteController.text.trim(),
        date: selectedDateTime,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        actorUserId: actor.userId,
        actorDisplayName: actor.displayName,
        actorRole: actor.role,
      );

      // Single authoritative creation: creates Firestore doc + wallet updates
      final transactionId =
          await transactionService.createTransaction(tempTransaction);

      // Step 2: Upload receipt if selected
      String? receiptUrl;
      if (_selectedReceiptImage != null) {
        receiptUrl = await _uploadReceiptToStorage(user.userId, transactionId);
      }

      // Step 3: Update transaction with receipt URL if uploaded
      if (receiptUrl != null) {
        final transaction = tempTransaction.copyWith(
          transactionId: transactionId,
          imageUrl: receiptUrl,
        );
        await transactionRepository.updateTransaction(transaction);
      }

      // Step 4: Create recurring rule if frequency is selected
      if (_selectedRecurringFrequency != null) {
        final recurringRuleRepository = RecurringRuleRepository();
        final nextDate = DateTime.now().add(
          _selectedRecurringFrequency == Frequency.daily
              ? const Duration(days: 1)
              : _selectedRecurringFrequency == Frequency.weekly
                  ? const Duration(days: 7)
                  : _selectedRecurringFrequency == Frequency.monthly
                      ? const Duration(days: 30)
                      : const Duration(days: 365),
        );

        final recurringRule = RecurringRuleModel(
          walletId: wallet.walletId,
          frequency: _selectedRecurringFrequency!,
          nextDate: nextDate,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          // Store template transaction data
          templateAmount: amount,
          templateCategoryId: _selectedCategoryId,
          templateType: _type.name,
          templateUserId: user.userId,
          templateHouseholdId: resolvedHouseholdId,
          templateNote: _noteController.text.trim(),
          templateCurrency: wallet.currency,
          templateActorUserId: actor.userId,
          templateActorDisplayName: actor.displayName,
          templateActorRole: actor.role,
        );

        await recurringRuleRepository.createRecurringRule(recurringRule);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedRecurringFrequency != null
                  ? 'Transaction saved with recurring rule'
                  : 'Transaction saved',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save transaction. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  WalletModel? _resolveSelectedWallet(List<WalletModel> wallets) {
    if (wallets.isEmpty) return null;
    if (_selectedWalletId == null) return wallets.first;
    try {
      return wallets.firstWhere((wallet) => wallet.walletId == _selectedWalletId);
    } catch (_) {
      return wallets.first;
    }
  }
}

class _HeaderCard extends StatelessWidget {
  final _UiCategory category;
  final String amountText;
  final VoidCallback onCategoryTap;

  const _HeaderCard({
    required this.category,
    required this.amountText,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCategoryTap,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: category.color.withOpacity(0.15),
              child: Icon(category.icon, color: category.color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to change category',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              amountText,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;

  const _TypeSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TypeChip(
            label: 'Expense',
            icon: Icons.arrow_downward,
            color: AppColors.error,
            selected: selected == TransactionType.expense,
            onTap: () => onChanged(TransactionType.expense),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TypeChip(
            label: 'Income',
            icon: Icons.arrow_upward,
            color: AppColors.success,
            selected: selected == TransactionType.income,
            onTap: () => onChanged(TransactionType.income),
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? color : Colors.transparent, width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : AppColors.textSecondary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _FieldTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label),
        subtitle: Text(value),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  final TextEditingController controller;

  const _NoteField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: 'Note',
        hintText: 'Add a note for this transaction',
        prefixIcon: Icon(Icons.note_outlined),
      ),
      maxLines: 2,
    );
  }
}

class _WalletInfoBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _WalletInfoBanner({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  final void Function(String value) onTap;
  final VoidCallback onBackspace;
  final VoidCallback? onSubmit;
  final bool isSaving;
  final bool isEdit;

  const _Keypad({
    required this.onTap,
    required this.onBackspace,
    required this.onSubmit,
    required this.isSaving,
    this.isEdit = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '.',
      '0',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 12,
            ),
            itemCount: buttons.length + 1,
            itemBuilder: (context, index) {
              if (index == buttons.length) {
                return _KeypadButton(
                  label: 'DEL',
                  onTap: onBackspace,
                );
              }
              final label = buttons[index];
              return _KeypadButton(
                label: label,
                onTap: () => onTap(label),
              );
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : onSubmit,
              icon: isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: Text(
                isSaving
                    ? 'Saving...'
                    : isEdit
                        ? 'Save Changes'
                        : 'Save Transaction',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _KeypadButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategorySheet extends ConsumerStatefulWidget {
  final String userId;
  final String? householdId;
  final String? selectedCategoryId;
  final ValueChanged<_UiCategory> onSelect;
  final Future<void> Function(CategoryType type) onAddCategory;
  final CategoryType initialType;
  final Future<void> Function(_UiCategory category) onArchive;

  const _CategorySheet({
    required this.userId,
    required this.householdId,
    required this.selectedCategoryId,
    required this.onSelect,
    required this.onAddCategory,
    required this.initialType,
    required this.onArchive,
  });

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialType == CategoryType.expense ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expenseAsync = ref.watch(
      categoriesStreamProvider(
        CategoryQueryParams(
          type: CategoryType.expense,
          userId: widget.userId,
          householdId: widget.householdId,
        ),
      ),
    );
    final incomeAsync = ref.watch(
      categoriesStreamProvider(
        CategoryQueryParams(
          type: CategoryType.income,
          userId: widget.userId,
          householdId: widget.householdId,
        ),
      ),
    );

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Expense'),
              Tab(text: 'Income'),
            ],
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
          ),
          SizedBox(
            height: 340,
            child: TabBarView(
              controller: _tabController,
              children: [
                expenseAsync.when(
                  data: (categories) {
                    final ui = _mapCategoriesLocal(categories);
                    debugPrint(
                        '[CATEGORY_PICKER] Expense categories updated: ${ui.length}');
                    return _CategoryGrid(
                      categories: ui,
                      type: CategoryType.expense,
                      onSelect: widget.onSelect,
                      onAddCategory: widget.onAddCategory,
                      onArchive: widget.onArchive,
                      selectedCategoryId: widget.selectedCategoryId,
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Unable to load categories',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),
                incomeAsync.when(
                  data: (categories) {
                    final ui = _mapCategoriesLocal(categories);
                    debugPrint(
                        '[CATEGORY_PICKER] Income categories updated: ${ui.length}');
                    return _CategoryGrid(
                      categories: ui,
                      type: CategoryType.income,
                      onSelect: widget.onSelect,
                      onAddCategory: widget.onAddCategory,
                      onArchive: widget.onArchive,
                      selectedCategoryId: widget.selectedCategoryId,
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Unable to load categories',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<_UiCategory> categories;
  final CategoryType type;
  final ValueChanged<_UiCategory> onSelect;
  final Future<void> Function(CategoryType type) onAddCategory;
  final Future<void> Function(_UiCategory category) onArchive;
  final String? selectedCategoryId;

  const _CategoryGrid({
    required this.categories,
    required this.type,
    required this.onSelect,
    required this.onAddCategory,
    required this.onArchive,
    required this.selectedCategoryId,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.9,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: categories.length + 1,
      itemBuilder: (context, index) {
        if (index == categories.length) {
          return _AddCategoryTile(type: type, onAddCategory: onAddCategory);
        }
        final category = categories[index];
        final isSelected = selectedCategoryId != null && selectedCategoryId == category.id;
        return InkWell(
          onTap: () => onSelect(category),
          onLongPress: category.isBuiltIn ? null : () => onArchive(category),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: category.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? Border.all(color: category.color, width: 2)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: category.color.withOpacity(0.2),
                  child: Icon(category.icon, color: category.color),
                ),
                const SizedBox(height: 8),
                Text(
                  category.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AddCategoryTile extends StatelessWidget {
  final CategoryType type;
  final Future<void> Function(CategoryType type) onAddCategory;

  const _AddCategoryTile({
    required this.type,
    required this.onAddCategory,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onAddCategory(type),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(Icons.add, color: Colors.white),
            ),
            SizedBox(height: 8),
            Text(
              'Add category',
              style: TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _UiCategory {
  final CategoryModel model;
  final IconData icon;
  final Color color;
  final bool isPlaceholder;

  const _UiCategory({
    required this.model,
    required this.icon,
    required this.color,
    this.isPlaceholder = false,
  });

  String get id => model.categoryId;
  String get name => model.name;
  TransactionType get type =>
      model.type == CategoryType.expense ? TransactionType.expense : TransactionType.income;
  bool get isBuiltIn => model.scope == CategoryScope.builtIn || model.isSystem;
}

const _categoryPalette = [
  AppColors.primary,
  AppColors.secondary,
  AppColors.warning,
  AppColors.info,
  AppColors.success,
  AppColors.error,
  AppColors.textSecondary,
];

const _categoryIconMap = {
  'food': Icons.fastfood,
  'transport': Icons.directions_car,
  'shopping': Icons.shopping_bag,
  'bills': Icons.receipt_long,
  'health': Icons.favorite_border,
  'entertainment': Icons.movie_filter,
  'salary': Icons.wallet,
  'bonus': Icons.card_giftcard,
  'investments': Icons.bar_chart,
  'freelance': Icons.work_outline,
  'gifts': Icons.card_giftcard_outlined,
  'other_income': Icons.more_horiz,
  'custom_income': Icons.category,
  'custom_expense': Icons.category,
};

List<_UiCategory> _mapCategoriesLocal(List<CategoryModel> categories) {
  return categories
      .map(
        (c) => _UiCategory(
          model: c,
          icon: _resolveCategoryIconLocal(c),
          color: _resolveCategoryColorLocal(c),
        ),
      )
      .toList();
}

_UiCategory _fallbackCategoryLocal(TransactionType type, {String? id}) {
  final model = CategoryModel(
    categoryId: id ?? 'other',
    name: 'Category',
    type: type == TransactionType.expense ? CategoryType.expense : CategoryType.income,
    scope: CategoryScope.personal,
  );
  return _UiCategory(
    model: model,
    icon: _defaultIconForTypeLocal(model.type),
    color: AppColors.textSecondary,
    isPlaceholder: true,
  );
}

IconData _resolveCategoryIconLocal(CategoryModel category) {
  final iconKey = category.iconName ?? category.categoryId;
  return _categoryIconMap[iconKey] ?? _defaultIconForTypeLocal(category.type);
}

IconData _defaultIconForTypeLocal(CategoryType type) =>
    type == CategoryType.expense ? Icons.category : Icons.category;

Color _resolveCategoryColorLocal(CategoryModel category) {
  final index = (category.colorIndex ?? 0) % _categoryPalette.length;
  return _categoryPalette[index];
}

class _ReceiptAttachmentTile extends StatelessWidget {
  final XFile? selectedImage;
  final VoidCallback onTap;

  const _ReceiptAttachmentTile({
    required this.selectedImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          selectedImage != null ? Icons.receipt : Icons.receipt_outlined,
          color: selectedImage != null ? AppColors.success : AppColors.primary,
        ),
        title: const Text('Receipt'),
        subtitle: Text(
          selectedImage != null ? 'Tap to change or remove' : 'Attach receipt image',
        ),
        trailing: selectedImage != null
            ? Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    File(selectedImage!.path),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _RecurringSelector extends StatelessWidget {
  final Frequency? selectedFrequency;
  final ValueChanged<Frequency?> onChanged;

  const _RecurringSelector({
    required this.selectedFrequency,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.repeat, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Recurring Transaction',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RecurringChip(
                  label: 'None',
                  selected: selectedFrequency == null,
                  onTap: () => onChanged(null),
                ),
                _RecurringChip(
                  label: 'Daily',
                  selected: selectedFrequency == Frequency.daily,
                  onTap: () => onChanged(Frequency.daily),
                ),
                _RecurringChip(
                  label: 'Weekly',
                  selected: selectedFrequency == Frequency.weekly,
                  onTap: () => onChanged(Frequency.weekly),
                ),
                _RecurringChip(
                  label: 'Monthly',
                  selected: selectedFrequency == Frequency.monthly,
                  onTap: () => onChanged(Frequency.monthly),
                ),
                _RecurringChip(
                  label: 'Yearly',
                  selected: selectedFrequency == Frequency.yearly,
                  onTap: () => onChanged(Frequency.yearly),
                ),
              ],
            ),
            if (selectedFrequency != null) ...[
              const SizedBox(height: 12),
              Text(
                'This transaction will repeat ${_getFrequencyText(selectedFrequency!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getFrequencyText(Frequency frequency) {
    switch (frequency) {
      case Frequency.daily:
        return 'every day';
      case Frequency.weekly:
        return 'every week';
      case Frequency.monthly:
        return 'every month';
      case Frequency.yearly:
        return 'every year';
    }
  }
}

class _RecurringChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RecurringChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.textSecondary.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
