import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/debt_provider.dart';
import '../../../data/models/debt_model.dart';

// MANUAL TEST CHECKLIST (Debts entry points)
// 1. From Home → Reports → Debt Summary CTA → should navigate to Debts list.
// 2. On Debts list → tap + icon → navigates to AddDebtScreen (no GoException).
// 3. Fill in a new debt → Save → screen pops → Debts list refreshes with new debt.
// 4. Net worth & Reports should reflect non-zero debt totals.
// 5. Test as both Head and Member; permissions should behave as expected.

class AddDebtScreen extends ConsumerStatefulWidget {
  const AddDebtScreen({super.key});

  @override
  ConsumerState<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends ConsumerState<AddDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _interestController = TextEditingController();
  DebtType _type = DebtType.iOwe;
  bool _useHousehold = false;
  DateTime? _dueDate;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authUserProvider);
    final user = userAsync.valueOrNull;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in')),
      );
    }

    final hasHousehold = (user.householdId?.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Debt'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Debt name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final parsed = double.tryParse(value ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<DebtType>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: DebtType.iOwe,
                    child: Text('I Owe'),
                  ),
                  DropdownMenuItem(
                    value: DebtType.owedToMe,
                    child: Text('Owed to Me'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _type = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _interestController,
                decoration: const InputDecoration(
                  labelText: 'Interest rate (%)',
                  hintText: 'Optional',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Due date (optional)'),
                subtitle: Text(
                  _dueDate != null
                      ? DateFormat('MMM d, yyyy').format(_dueDate!)
                      : 'Not set',
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: _dueDate ?? now,
                      firstDate: now.subtract(const Duration(days: 0)),
                      lastDate: DateTime(now.year + 5),
                    );
                    if (selected != null) {
                      setState(() {
                        _dueDate = selected;
                      });
                    }
                  },
                  child: const Text('Pick date'),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Household debt'),
                subtitle: Text(hasHousehold
                    ? 'Shared with household'
                    : 'No household available'),
                value: _useHousehold && hasHousehold,
                onChanged: hasHousehold
                    ? (value) {
                        setState(() {
                          _useHousehold = value;
                        });
                      }
                    : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : () => _handleSubmit(user),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Debt'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit(dynamic user) async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final interest = double.tryParse(_interestController.text.trim().isEmpty
            ? '0'
            : _interestController.text.trim()) ??
        0;

    final debt = DebtModel(
      debtId: '',
      userId: user.userId,
      householdId: _useHousehold ? user.householdId : null,
      name: _nameController.text.trim(),
      amount: amount,
      interestRate: interest,
      dueDate: _dueDate,
      type: _type,
      paidAmount: 0,
      creditorDebtor: null,
    );

    setState(() {
      _submitting = true;
    });

    try {
      await ref.read(debtNotifierProvider.notifier).createDebt(debt);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debt added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }
}
