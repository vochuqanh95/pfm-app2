import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/debt_model.dart';
import '../../providers/debt_provider.dart';

// MANUAL TEST - EDIT DEBT INTEREST
// 1. Create a new debt with amount 2000, interest 0.00, due date in the future.
// 2. Open Debt Detail -> verify interest shows 0.00%.
// 3. Tap edit icon -> change interest to 3.50 -> Save Changes.
// 4. Back to Debt Detail:
//    - Interest Rate should show 3.50%.
//    - Estimated interest should be > 0.
// 5. Reload the app, open the same debt again:
//    - Interest Rate persists as 3.50%.
// 6. Change again to 0.03 and repeat to verify small percentages also persist.
class EditDebtScreen extends ConsumerStatefulWidget {
  final String debtId;

  const EditDebtScreen({super.key, required this.debtId});

  @override
  ConsumerState<EditDebtScreen> createState() => _EditDebtScreenState();
}

class _EditDebtScreenState extends ConsumerState<EditDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _interestController = TextEditingController();
  final _descriptionController = TextEditingController();
  DebtType _type = DebtType.iOwe;
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _interestController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debtAsync = ref.watch(debtProvider(widget.debtId));

    return debtAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Edit Debt')),
        body: Center(child: Text('Unable to load debt: $error')),
      ),
      data: (debt) {
        if (debt == null) {
          return const Scaffold(
            body: Center(child: Text('Debt not found')),
          );
        }

        _prefill(debt);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit Debt'),
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
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Due date',
                      border: OutlineInputBorder(),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _dueDate != null
                            ? DateFormat('yyyy-MM-dd').format(_dueDate!)
                            : 'No due date',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dueDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _dueDate = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : () => _handleSave(debt),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _prefill(DebtModel debt) {
    if (_nameController.text.isEmpty) {
      _nameController.text = debt.name;
    }
    if (_amountController.text.isEmpty) {
      _amountController.text = debt.amount.toStringAsFixed(2);
    }
    if (_interestController.text.isEmpty) {
      _interestController.text = debt.interestRate.toStringAsFixed(2);
    }
    if (_descriptionController.text.isEmpty && (debt.description ?? '').isNotEmpty) {
      _descriptionController.text = debt.description!;
    }
    _type = debt.type ?? DebtType.iOwe;
    _dueDate = debt.dueDate;
  }

  Future<void> _handleSave(DebtModel existing) async {
    if (!_formKey.currentState!.validate()) return;

    debugPrint('[DEBT_EDIT] onSave tapped for ${existing.id}');
    final amount = double.parse(_amountController.text);
    final rawInterest = _interestController.text.trim();
    final sanitizedInterest =
        rawInterest.replaceAll('%', '').replaceAll(',', '.');
    final parsedInterest = double.tryParse(sanitizedInterest);
    final interest = parsedInterest ?? 0.0;
    final clampedPaid = (existing.paidAmount ?? 0) > amount
        ? amount
        : (existing.paidAmount ?? 0);

    setState(() => _saving = true);
    try {
      final updated = existing.copyWith(
        name: _nameController.text.trim(),
        amount: amount,
        interestRate: interest,
        dueDate: _dueDate,
        type: _type,
        paidAmount: clampedPaid,
        creditorDebtor: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : existing.creditorDebtor,
      );
      debugPrint(
          '[DEBT_EDIT] Saving debt ${existing.id} with interestRate=$interest');
      await ref.read(debtRepositoryProvider).updateDebt(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debt updated')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update debt: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

