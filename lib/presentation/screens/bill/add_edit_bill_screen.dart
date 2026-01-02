import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/bill_model.dart';
import '../../providers/bill_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/household_provider.dart';

class AddEditBillScreen extends ConsumerStatefulWidget {
  final BillModel? bill;

  const AddEditBillScreen({super.key, this.bill});

  @override
  ConsumerState<AddEditBillScreen> createState() => _AddEditBillScreenState();
}

class _AddEditBillScreenState extends ConsumerState<AddEditBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  String _scope = 'personal';
  String _currency = 'USD';
  BillRecurrence _recurrence = BillRecurrence.none;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  int _remindDaysBefore = 3;
  String? _responsibleUserId;
  bool _isSaving = false;

  bool get isEdit => widget.bill != null;

  @override
  void initState() {
    super.initState();
    if (widget.bill != null) {
      _nameController.text = widget.bill!.name;
      _amountController.text = widget.bill!.amount.toString();
      _scope = widget.bill!.scope;
      _currency = widget.bill!.currency;
      _recurrence = widget.bill!.recurrence;
      _dueDate = widget.bill!.dueDate;
      _remindDaysBefore = widget.bill!.remindDaysBefore;
      _responsibleUserId = widget.bill!.responsibleUserId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authUserProvider);
    final householdAsync = ref.watch(currentUserHouseholdProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(body: Center(child: Text('Unable to load user data'))),
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text('Please sign in')));
        }

        final householdId = householdAsync.maybeWhen(
          data: (h) => h?.householdId ?? user.householdId ?? '',
          orElse: () => user.householdId ?? '',
        );

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            title: Text(isEdit ? 'Edit Bill' : 'Add Bill'),
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Name field
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Bill Name',
                      hintText: 'e.g., Electricity, Water, Rent',
                      prefixIcon: Icon(Icons.receipt),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a bill name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Amount field
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an amount';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Please enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Currency dropdown
                  DropdownButtonFormField<String>(
                    value: _currency,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      prefixIcon: Icon(Icons.currency_exchange),
                      border: OutlineInputBorder(),
                    ),
                    items: ['USD', 'VND']
                        .map((currency) => DropdownMenuItem(
                              value: currency,
                              child: Text(currency),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _currency = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Due date picker
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dueDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (date != null) {
                        setState(() => _dueDate = date);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Due Date',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(DateFormat('MMM dd, yyyy').format(_dueDate)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recurrence dropdown
                  DropdownButtonFormField<BillRecurrence>(
                    value: _recurrence,
                    decoration: const InputDecoration(
                      labelText: 'Recurrence',
                      prefixIcon: Icon(Icons.repeat),
                      border: OutlineInputBorder(),
                    ),
                    items: BillRecurrence.values
                        .map((recurrence) => DropdownMenuItem(
                              value: recurrence,
                              child: Text(_getRecurrenceLabel(recurrence)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _recurrence = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Scope (family/personal)
                  if (user.isHead) ...[
                    DropdownButtonFormField<String>(
                      value: _scope,
                      decoration: const InputDecoration(
                        labelText: 'Bill Type',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'family', child: Text('Family Bill')),
                        DropdownMenuItem(value: 'personal', child: Text('Personal Bill')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _scope = value;
                            if (value == 'personal') {
                              _responsibleUserId = null;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Responsible user (only for family bills)
                  if (_scope == 'family' && user.isHead) ...[
                    DropdownButtonFormField<String?>(
                      value: _responsibleUserId,
                      decoration: const InputDecoration(
                        labelText: 'Responsible Person',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                        helperText: 'Who should pay this bill?',
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Head (${user.name})'),
                        ),
                        // TODO: Add household members here
                        // For now, just showing head
                      ],
                      onChanged: (value) {
                        setState(() => _responsibleUserId = value);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Remind days before
                  DropdownButtonFormField<int>(
                    value: _remindDaysBefore,
                    decoration: const InputDecoration(
                      labelText: 'Remind Me',
                      prefixIcon: Icon(Icons.notifications),
                      border: OutlineInputBorder(),
                    ),
                    items: [1, 2, 3, 5, 7, 14]
                        .map((days) => DropdownMenuItem(
                              value: days,
                              child: Text('$days day${days == 1 ? '' : 's'} before'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _remindDaysBefore = value);
                      }
                    },
                  ),
                  const SizedBox(height: 32),

                  // Save button
                  ElevatedButton(
                    onPressed: _isSaving ? null : () => _saveBill(user, householdId),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEdit ? 'Update Bill' : 'Create Bill'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getRecurrenceLabel(BillRecurrence recurrence) {
    switch (recurrence) {
      case BillRecurrence.none:
        return 'One-time';
      case BillRecurrence.monthly:
        return 'Monthly';
      case BillRecurrence.yearly:
        return 'Yearly';
      case BillRecurrence.custom:
        return 'Custom';
    }
  }

  Future<void> _saveBill(dynamic user, String householdId) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final amount = double.parse(_amountController.text.trim());

      final bill = BillModel(
        billId: widget.bill?.billId ?? '',
        userId: user.userId,
        householdId: _scope == 'family' ? householdId : null,
        name: _nameController.text.trim(),
        amount: amount,
        currency: _currency,
        dueDate: _dueDate,
        status: widget.bill?.status ?? BillStatus.unpaid,
        createdAt: widget.bill?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        scope: _scope,
        createdByUserId: user.userId,
        responsibleUserId: _responsibleUserId ?? user.userId,
        recurrence: _recurrence,
        remindDaysBefore: _remindDaysBefore,
      );

      final notifier = ref.read(billNotifierProvider.notifier);

      if (isEdit) {
        await notifier.updateBill(bill);
      } else {
        await notifier.createBill(bill);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEdit ? 'Bill updated' : 'Bill created')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
