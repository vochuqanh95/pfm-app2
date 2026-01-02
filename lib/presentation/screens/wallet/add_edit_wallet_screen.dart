import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/wallet_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/household_provider.dart';
import '../../providers/wallet_provider.dart';

class AddEditWalletScreen extends ConsumerStatefulWidget {
  final WalletModel? wallet;

  const AddEditWalletScreen({super.key, this.wallet});

  @override
  ConsumerState<AddEditWalletScreen> createState() => _AddEditWalletScreenState();
}

class _AddEditWalletScreenState extends ConsumerState<AddEditWalletScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _openingBalanceController;
  late WalletType _type;
  late String _currency;
  late _WalletScopeOption _scopeOption;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final wallet = widget.wallet;
    _nameController = TextEditingController(text: wallet?.name ?? '');
    _openingBalanceController =
        TextEditingController(text: wallet == null ? '0' : wallet.openingBalance.toStringAsFixed(2));
    _type = wallet?.type ?? WalletType.cash;
    _currency = wallet?.currency ?? 'USD';
    _scopeOption = wallet == null
        ? _WalletScopeOption.householdShared
        : _mapScopeToOption(wallet.scope);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authUserProvider);
    final householdAsync = ref.watch(currentUserHouseholdProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(body: Center(child: Text('Unable to load user'))),
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text('Please sign in.')));
        }

        final householdId = householdAsync.maybeWhen(
          data: (household) => household?.householdId ?? user.householdId ?? '',
          orElse: () => user.householdId ?? '',
        );

        final isEdit = widget.wallet != null;
        final isHead = user.isHead;
        if (!isHead && widget.wallet == null && _scopeOption != _WalletScopeOption.personal) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _scopeOption = _WalletScopeOption.personal);
            }
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(isEdit ? 'Edit Wallet' : 'Add Wallet'),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Wallet Name',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<WalletType>(
                      value: _type,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: WalletType.values
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(_typeLabel(type)),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _type = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _openingBalanceController,
                      decoration: const InputDecoration(
                        labelText: 'Opening Balance',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      enabled: !isEdit,
                      validator: (val) {
                        if (isEdit) return null;
                        final parsed = double.tryParse(val ?? '');
                        if (parsed == null) return 'Enter a valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _currency,
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      onChanged: (val) => _currency = val.trim().isEmpty ? 'USD' : val.trim(),
                    ),
                    const SizedBox(height: 12),
                    if (isHead)
                      DropdownButtonFormField<_WalletScopeOption>(
                        value: _scopeOption,
                        decoration: const InputDecoration(
                          labelText: 'Scope',
                          prefixIcon: Icon(Icons.group),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: _WalletScopeOption.householdShared,
                            child: Text('Shared with household'),
                          ),
                          DropdownMenuItem(
                            value: _WalletScopeOption.memberPrivate,
                            child: Text('Member private'),
                          ),
                          DropdownMenuItem(
                            value: _WalletScopeOption.personal,
                            child: Text('Personal (only you)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _scopeOption = val);
                        },
                      )
                    else
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.lock_outline),
                        title: Text('Personal wallet'),
                        subtitle: Text('Visible only to you.'),
                      ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _isSaving ? null : () => _save(userId: user.userId, householdId: householdId, isHead: isHead),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(isEdit ? 'Save Changes' : 'Create Wallet'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _save({required String userId, required String householdId, required bool isHead}) async {
    if (!_formKey.currentState!.validate()) return;
    final targetScope = isHead ? _scopeOption : _WalletScopeOption.personal;
    if (targetScope != _WalletScopeOption.personal && householdId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join or create a household first.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final repo = ref.read(walletRepositoryProvider);

    try {
      if (widget.wallet == null) {
        final opening = double.tryParse(_openingBalanceController.text) ?? 0;
        switch (targetScope) {
          case _WalletScopeOption.householdShared:
            await repo.createHouseholdWallet(
              householdId: householdId,
              name: _nameController.text.trim(),
              type: _type.name,
              currency: _currency,
              openingBalance: opening,
              shared: true,
              ownerUserId: null,
            );
            break;
          case _WalletScopeOption.memberPrivate:
            await repo.createHouseholdWallet(
              householdId: householdId,
              name: _nameController.text.trim(),
              type: _type.name,
              currency: _currency,
              openingBalance: opening,
              shared: false,
              ownerUserId: userId,
            );
            break;
          case _WalletScopeOption.personal:
            await repo.createPersonalWallet(
              ownerUserId: userId,
              name: _nameController.text.trim(),
              type: _type.name,
              currency: _currency,
              openingBalance: opening,
            );
            break;
        }
      } else {
        final mappedScope = _mapOptionToScope(targetScope);
        final notifier = ref.read(walletNotifierProvider.notifier);
        final updated = widget.wallet!.copyWith(
          name: _nameController.text.trim(),
          type: _type,
          scope: mappedScope,
          currency: _currency,
          householdId: mappedScope == WalletScope.personal ? null : householdId,
          userId: mappedScope == WalletScope.householdShared ? null : userId,
          updatedAt: DateTime.now(),
        );
        await notifier.updateWallet(updated);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallet saved')),
        );
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save wallet')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _typeLabel(WalletType type) {
    switch (type) {
      case WalletType.bank:
        return 'Bank';
      case WalletType.card:
        return 'Card';
      case WalletType.ewallet:
        return 'E-Wallet';
      case WalletType.cash:
      default:
        return 'Cash';
    }
  }

  _WalletScopeOption _mapScopeToOption(WalletScope scope) {
    switch (scope) {
      case WalletScope.householdShared:
        return _WalletScopeOption.householdShared;
      case WalletScope.memberPrivate:
        return _WalletScopeOption.memberPrivate;
      case WalletScope.personal:
      default:
        return _WalletScopeOption.personal;
    }
  }

  WalletScope _mapOptionToScope(_WalletScopeOption option) {
    switch (option) {
      case _WalletScopeOption.householdShared:
        return WalletScope.householdShared;
      case _WalletScopeOption.memberPrivate:
        return WalletScope.memberPrivate;
      case _WalletScopeOption.personal:
      default:
        return WalletScope.personal;
    }
  }
}

enum _WalletScopeOption { householdShared, memberPrivate, personal }
