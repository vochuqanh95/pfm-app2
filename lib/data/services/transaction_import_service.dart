import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../core/utils/actor_utils.dart';
import '../models/household_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';
import '../models/wallet_model.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/wallet_repository.dart';
import 'transaction_service.dart';

class ImportSummary {
  final int totalRows;
  final int createdCount;
  final int duplicateCount;
  final int errorCount;

  const ImportSummary({
    required this.totalRows,
    required this.createdCount,
    required this.duplicateCount,
    required this.errorCount,
  });
}

class TransactionImportService {
  TransactionImportService({
    required TransactionService transactionService,
    required TransactionRepository transactionRepository,
    WalletRepository? walletRepository,
  })  : _transactionService = transactionService,
        _transactionRepository = transactionRepository,
        _walletRepository = walletRepository ?? WalletRepository();

  final TransactionService _transactionService;
  final TransactionRepository _transactionRepository;
  final WalletRepository _walletRepository;

  Future<ImportSummary> importFromCsv({
    required UserModel user,
    HouseholdModel? household,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );

    if (result == null || result.files.single.path == null) {
      throw Exception('No file selected');
    }

    final path = result.files.single.path!;
    debugPrint('[IMPORT] File picked: $path');

    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Selected file does not exist');
    }

    final content = await file.readAsString();
    final rows = const CsvToListConverter().convert(content);
    debugPrint('[IMPORT] Parsed ${rows.length} CSV rows');

    if (rows.isEmpty) {
      throw Exception('CSV file is empty');
    }

    final walletLookup = await _buildWalletLookup(user, household);
    final parsed = _parseCandidates(rows, walletLookup, household);
    final candidates = parsed.candidates;
    final totalRows = parsed.totalRows;

    final groupedByWallet = <String, List<_TransactionCandidate>>{};
    for (final candidate in candidates) {
      groupedByWallet.putIfAbsent(candidate.wallet.walletId, () => []).add(candidate);
    }

    final existingKeysByWallet = <String, Set<String>>{};
    for (final entry in groupedByWallet.entries) {
      final dates = entry.value.map((c) => c.date).toList();
      dates.sort();
      final start = dates.first.subtract(const Duration(days: 3));
      final end = dates.last.add(const Duration(days: 3));
      final existing = await _transactionRepository.getTransactionsByDateRange(
        walletId: entry.key,
        startDate: start,
        endDate: end,
      );
      existingKeysByWallet[entry.key] = existing.map(_dedupeKeyFromModel).toSet();
    }

    final actor = buildActorInfo(user);
    int createdCount = 0;
    int duplicateCount = 0;
    int errorCount = 0;

    for (final candidate in candidates) {
      final walletKey = candidate.wallet.walletId;
      final keySet = existingKeysByWallet[walletKey] ?? <String>{};
      final dedupeKey = _dedupeKeyFromCandidate(candidate);
      if (keySet.contains(dedupeKey)) {
        duplicateCount++;
        continue;
      }

      final householdId =
          candidate.householdId ?? candidate.wallet.householdId ?? household?.householdId;
      final amount = candidate.type == TransactionType.expense
          ? candidate.amount.abs()
          : candidate.amount.abs();

      final transaction = TransactionModel(
        transactionId: '',
        userId: user.userId,
        householdId: householdId,
        categoryId: candidate.categoryId,
        walletId: candidate.wallet.walletId,
        amount: amount,
        currency: candidate.currency ?? candidate.wallet.currency,
        type: candidate.type,
        note: candidate.note ?? '',
        date: candidate.date,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        actorUserId: actor.userId,
        actorDisplayName: actor.displayName,
        actorRole: actor.role,
      );

      try {
        await _transactionService.createTransaction(transaction);
        createdCount++;
        keySet.add(dedupeKey);
        existingKeysByWallet[walletKey] = keySet;
      } catch (e, st) {
        errorCount++;
        debugPrint('[IMPORT] Failed to create transaction: $e\n$st');
      }
    }

    final invalidCount = totalRows - candidates.length;
    final summary = ImportSummary(
      totalRows: totalRows,
      createdCount: createdCount,
      duplicateCount: duplicateCount,
      errorCount: errorCount + invalidCount,
    );

    debugPrint(
      '[IMPORT] Created ${summary.createdCount}, duplicates=${summary.duplicateCount}, errors=${summary.errorCount} (invalid_rows=$invalidCount)',
    );

    return summary;
  }

  _ParsedCandidates _parseCandidates(
    List<List<dynamic>> rows,
    Map<String, WalletModel> walletLookup,
    HouseholdModel? household,
  ) {
    if (rows.isEmpty) {
      return const _ParsedCandidates(candidates: [], totalRows: 0);
    }

    final header = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
    final hasHeader = header.contains('amount') && header.contains('date');
    final startIndex = hasHeader ? 1 : 0;
    final candidates = <_TransactionCandidate>[];
    final totalRows = rows.length - startIndex;

    for (var i = startIndex; i < rows.length; i++) {
      final row = rows[i];
      final amountStr = _valueFor(row, header, 'amount', fallbackIndex: 2);
      final dateStr = _valueFor(row, header, 'date', fallbackIndex: 7);
      final walletIdRaw =
          _valueFor(row, header, 'wallet_id', fallbackIndex: 5) ??
              _valueFor(row, header, 'wallet', fallbackIndex: 5);
      final walletName = _valueFor(row, header, 'wallet_name', fallbackIndex: 6);
      final categoryId = _valueFor(row, header, 'category', fallbackIndex: 4);
      final typeRaw = _valueFor(row, header, 'type', fallbackIndex: 1);
      final currency = _valueFor(row, header, 'currency', fallbackIndex: 3);
      final note = _valueFor(row, header, 'note', fallbackIndex: 8) ??
          _valueFor(row, header, 'description') ??
          '';
      final householdId =
          _valueFor(row, header, 'household_id', fallbackIndex: 12) ?? household?.householdId;

      if (amountStr == null || dateStr == null || categoryId == null) {
        continue;
      }

      final parsedDate = _parseDate(dateStr);
      final parsedAmount = _parseAmount(amountStr);
      if (parsedDate == null || parsedAmount == null) {
        continue;
      }

      final type = _parseType(typeRaw, parsedAmount);
      if (type == null || type == TransactionType.transfer) {
        continue;
      }

      final wallet = _resolveWallet(walletIdRaw, walletName, walletLookup);
      if (wallet == null) {
        continue;
      }

      candidates.add(
        _TransactionCandidate(
          amount: parsedAmount.abs(),
          type: type,
          note: note,
          categoryId: categoryId,
          wallet: wallet,
          currency: currency,
          date: parsedDate,
          householdId: householdId,
        ),
      );
    }

    return _ParsedCandidates(candidates: candidates, totalRows: totalRows);
  }

  WalletModel? _resolveWallet(
    String? walletIdRaw,
    String? walletName,
    Map<String, WalletModel> walletLookup,
  ) {
    if (walletIdRaw != null) {
      final byId = walletLookup[walletIdRaw];
      if (byId != null) return byId;
    }
    if (walletName != null && walletName.trim().isNotEmpty) {
      final key = walletName.trim().toLowerCase();
      for (final wallet in walletLookup.values) {
        if (wallet.name.toLowerCase() == key) {
          return wallet;
        }
      }
    }
    return null;
  }

  double? _parseAmount(String raw) {
    final cleaned = raw.replaceAll(',', '').trim();
    return double.tryParse(cleaned);
  }

  DateTime? _parseDate(String raw) {
    final trimmed = raw.trim();
    final direct = DateTime.tryParse(trimmed);
    if (direct != null) return direct;

    final formats = [
      'yyyy-MM-dd',
      'dd/MM/yyyy',
      'MM/dd/yyyy',
      'yyyy/MM/dd',
    ];

    for (final pattern in formats) {
      try {
        final parsed = DateFormat(pattern).parse(trimmed);
        return parsed;
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  TransactionType? _parseType(String? raw, double amount) {
    if (raw != null && raw.isNotEmpty) {
      final normalized = raw.trim().toLowerCase();
      for (final value in TransactionType.values) {
        if (value.name == normalized) return value;
      }
    }
    return amount < 0 ? TransactionType.expense : TransactionType.income;
  }

  String? _valueFor(
    List<dynamic> row,
    List<String> header,
    String key, {
    int? fallbackIndex,
  }) {
    final index = header.indexOf(key);
    if (index != -1 && index < row.length) {
      return row[index]?.toString().trim();
    }
    if (fallbackIndex != null && fallbackIndex < row.length) {
      return row[fallbackIndex]?.toString().trim();
    }
    return null;
  }

  String _dedupeKeyFromCandidate(_TransactionCandidate candidate) {
    final normalizedNote = (candidate.note ?? '').trim().toLowerCase();
    return '${candidate.date.toIso8601String()}|${_amountKey(candidate.amount)}|${candidate.wallet.walletId}|$normalizedNote';
  }

  String _dedupeKeyFromModel(TransactionModel model) {
    final normalizedNote = (model.note).trim().toLowerCase();
    return '${model.date.toIso8601String()}|${_amountKey(model.amount)}|${model.walletId}|$normalizedNote';
  }

  String _amountKey(double amount) {
    return amount.toStringAsFixed(2);
  }

  Future<Map<String, WalletModel>> _buildWalletLookup(
    UserModel user,
    HouseholdModel? household,
  ) async {
    final map = <String, WalletModel>{};
    final householdId = household?.householdId ?? user.householdId ?? '';

    try {
      if (householdId.isNotEmpty) {
        final wallets = await _walletRepository.getHouseholdWallets(
          householdId,
          userId: user.userId,
        );
        for (final wallet in wallets) {
          map[wallet.walletId] = wallet;
        }
      } else {
        final wallets = await _walletRepository.getPersonalWallets(user.userId);
        for (final wallet in wallets) {
          map[wallet.walletId] = wallet;
        }
      }
    } catch (e) {
      debugPrint('[IMPORT] Failed to load wallets for import: $e');
    }

    return map;
  }
}

class _TransactionCandidate {
  final double amount;
  final TransactionType type;
  final String? note;
  final String categoryId;
  final WalletModel wallet;
  final String? currency;
  final DateTime date;
  final String? householdId;

  const _TransactionCandidate({
    required this.amount,
    required this.type,
    required this.note,
    required this.categoryId,
    required this.wallet,
    required this.currency,
    required this.date,
    required this.householdId,
  });
}

class _ParsedCandidates {
  final List<_TransactionCandidate> candidates;
  final int totalRows;

  const _ParsedCandidates({
    required this.candidates,
    required this.totalRows,
  });
}
