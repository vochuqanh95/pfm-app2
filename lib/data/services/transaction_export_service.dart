import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/household_model.dart';
import '../../core/enums/app_currency.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';
import '../models/wallet_model.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/wallet_repository.dart';

class TransactionExportService {
  TransactionExportService({
    required TransactionRepository transactionRepository,
    WalletRepository? walletRepository,
  })  : _transactionRepository = transactionRepository,
        _walletRepository = walletRepository ?? WalletRepository();

  final TransactionRepository _transactionRepository;
  final WalletRepository _walletRepository;

  static const _csvHeaders = [
    'id',
    'type',
    'amount',
    'currency',
    'category',
    'wallet_id',
    'wallet_name',
    'date',
    'note',
    'actor_name',
    'actor_role',
    'user_id',
    'household_id',
  ];

  Future<List<TransactionModel>> fetchExportableTransactions({
    required UserModel user,
    HouseholdModel? household,
  }) async {
    final householdId = household?.householdId ?? user.householdId ?? '';

    if (user.isHead && householdId.isNotEmpty) {
      return _transactionRepository.getTransactionsForHousehold(
        householdId: householdId,
      );
    }

    return _transactionRepository.getTransactionsForUser(
      userId: user.userId,
      householdId: householdId.isEmpty ? null : householdId,
    );
  }

  Future<File> exportTransactionsForUserCsv({
    required UserModel user,
    HouseholdModel? household,
    AppCurrency? currencyPreference,
  }) async {
    debugPrint('[EXPORT] Starting export for user=${user.userId}, household=${household?.householdId}');

    final transactions = await fetchExportableTransactions(
      user: user,
      household: household,
    );

    final walletLookup = await _buildWalletLookup(user, household);

    return _exportCsv(
      transactions: transactions,
      household: household,
      user: user,
      walletLookup: walletLookup,
      currencyPreference: currencyPreference,
    );
  }

  Future<File> exportTransactionsForUserExcel({
    required UserModel user,
    HouseholdModel? household,
    AppCurrency? currencyPreference,
  }) async {
    debugPrint('[EXPORT] Starting export (excel) for user=${user.userId}, household=${household?.householdId}');

    final transactions = await fetchExportableTransactions(
      user: user,
      household: household,
    );

    final walletLookup = await _buildWalletLookup(user, household);

    return _exportExcel(
      transactions: transactions,
      household: household,
      user: user,
      walletLookup: walletLookup,
      currencyPreference: currencyPreference,
    );
  }

  Future<File> exportTransactionsToCsv({
    required List<TransactionModel> transactions,
    required UserModel user,
    HouseholdModel? household,
    String filePrefix = 'transactions',
    AppCurrency? currencyPreference,
  }) async {
    debugPrint(
        '[EXPORT] Starting export (csv) for user=${user.userId}, rows=${transactions.length}, household=${household?.householdId}');
    final walletLookup = await _buildWalletLookup(user, household);
    return _exportCsv(
      transactions: transactions,
      household: household,
      user: user,
      walletLookup: walletLookup,
      filePrefix: filePrefix,
      currencyPreference: currencyPreference,
    );
  }

  Future<File> exportTransactionsToExcel({
    required List<TransactionModel> transactions,
    required UserModel user,
    HouseholdModel? household,
    String filePrefix = 'transactions',
    AppCurrency? currencyPreference,
  }) async {
    debugPrint(
        '[EXPORT] Starting export (excel) for user=${user.userId}, rows=${transactions.length}, household=${household?.householdId}');
    final walletLookup = await _buildWalletLookup(user, household);
    return _exportExcel(
      transactions: transactions,
      household: household,
      user: user,
      walletLookup: walletLookup,
      filePrefix: filePrefix,
      currencyPreference: currencyPreference,
    );
  }

  Future<File> _exportCsv({
    required List<TransactionModel> transactions,
    required HouseholdModel? household,
    required UserModel user,
    required Map<String, WalletModel> walletLookup,
    String filePrefix = 'transactions',
    AppCurrency? currencyPreference,
  }) async {
    final rows = <List<dynamic>>[];
    rows.add(_csvHeaders);
    for (final tx in transactions) {
      rows.add(_toCsvRow(tx, walletLookup, currencyPreference));
    }

    final csv = const ListToCsvConverter().convert(rows);
    final directory = await _resolveExportDirectory();
    final filename = _buildFileName(
      household: household,
      user: user,
      extension: 'csv',
      prefix: filePrefix,
    );
    final file = File('${directory.path}${Platform.pathSeparator}$filename');
    await file.create(recursive: true);
    await file.writeAsString(csv, encoding: utf8);

    debugPrint('[EXPORT] Exporting ${transactions.length} transactions to ${file.path}');
    return file;
  }

  Future<File> _exportExcel({
    required List<TransactionModel> transactions,
    required HouseholdModel? household,
    required UserModel user,
    required Map<String, WalletModel> walletLookup,
    String filePrefix = 'transactions',
    AppCurrency? currencyPreference,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Transactions'];
    sheet.appendRow(_csvHeaders.map((e) => TextCellValue(e)).toList());

    for (final tx in transactions) {
      sheet.appendRow(_toExcelRow(tx, walletLookup, currencyPreference));
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Excel file');
    }

    final directory = await _resolveExportDirectory();
    final filename = _buildFileName(
      household: household,
      user: user,
      extension: 'xlsx',
      prefix: filePrefix,
    );
    final file = File('${directory.path}${Platform.pathSeparator}$filename');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);

    debugPrint('[EXPORT] Exporting ${transactions.length} transactions to ${file.path}');
    return file;
  }

  List<dynamic> _toCsvRow(
    TransactionModel tx,
    Map<String, WalletModel> walletLookup,
    AppCurrency? currencyPreference,
  ) {
    final wallet = walletLookup[tx.walletId];
    return [
      tx.transactionId,
      tx.type.name,
      tx.amount.toString(),
      (currencyPreference ?? AppCurrency.fromCode(tx.currency)).code,
      tx.categoryId,
      tx.walletId,
      wallet?.name ?? '',
      _formatDate(tx.date),
      tx.note,
      tx.actorDisplayName ?? '',
      tx.actorRole ?? '',
      tx.userId,
      tx.householdId ?? '',
    ];
  }

  List<CellValue?> _toExcelRow(
    TransactionModel tx,
    Map<String, WalletModel> walletLookup,
    AppCurrency? currencyPreference,
  ) {
    final csvRow = _toCsvRow(tx, walletLookup, currencyPreference);
    return csvRow
        .map<CellValue?>((value) => TextCellValue(value?.toString() ?? ''))
        .toList();
  }

  String _formatDate(DateTime date) {
    return date.toIso8601String();
  }

  String _buildFileName({
    required HouseholdModel? household,
    required UserModel user,
    required String extension,
    String prefix = 'transactions',
  }) {
    final suffix = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final label = household != null && household.name.trim().isNotEmpty
        ? household.name
        : (household?.householdId ??
            user.householdId ??
            user.userId.substring(0, min(user.userId.length, 8)));
    final sanitized = label.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return '${prefix}_${sanitized}_$suffix.$extension';
  }

  Future<Directory> _resolveExportDirectory() async {
    Directory? dir;

    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (status.isGranted || status.isLimited) {
        dir = await getExternalStorageDirectory();
      }
    }

    dir ??= await getApplicationDocumentsDirectory();

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
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
      debugPrint('[EXPORT] Failed to load wallets for export: $e');
    }

    return map;
  }
}
