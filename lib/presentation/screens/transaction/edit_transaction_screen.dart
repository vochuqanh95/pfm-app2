import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import 'add_transaction_screen.dart';

// MANUAL TEST CHECKLIST (Edit Transaction)
// 1) Open a transaction from Recent -> Edit -> change amount 50 -> 80: wallet adjusts by +30/-30 once, same doc updates.
// 2) Edit note/category only: wallet balance unchanged, transaction shows new fields.
// 3) Transfer edit is blocked with a friendly message.
// 4) Cancel edit (back) leaves transaction unchanged.

class EditTransactionScreen extends ConsumerWidget {
  final String transactionId;

  const EditTransactionScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(transactionRepositoryProvider);
    return FutureBuilder<TransactionModel?>(
      future: repository.getTransactionById(transactionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(
            body: Center(child: Text('Transaction not found')),
          );
        }

        final transaction = snapshot.data!;
        return AddTransactionScreen(
          initialType: transaction.type,
          existingTransaction: transaction,
        );
      },
    );
  }
}
