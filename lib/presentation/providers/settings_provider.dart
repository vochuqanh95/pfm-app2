import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/enums/app_currency.dart';
import '../../core/enums/app_language.dart';
import '../../core/models/app_settings.dart';
import '../../data/repositories/user_repository.dart';
import 'auth_provider.dart';

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AsyncValue<AppSettings>>((ref) {
  final repo = ref.watch(userRepositoryProvider);
  final notifier = AppSettingsNotifier(repository: repo);

  // React to auth changes
  ref.listen(authStateProvider, (previous, next) {
    notifier.onAuthChanged(next.valueOrNull);
  });

  // Initialize with current auth state
  notifier.onAuthChanged(ref.read(authStateProvider).valueOrNull);
  return notifier;
});

class AppSettingsNotifier extends StateNotifier<AsyncValue<AppSettings>> {
  AppSettingsNotifier({
    required UserRepository repository,
  })  : _repository = repository,
        super(const AsyncValue.data(AppSettings()));

  final UserRepository _repository;
  String? _currentUserId;

  Future<void> onAuthChanged(User? user) async {
    _currentUserId = user?.uid;
    if (user == null) {
      state = const AsyncValue.data(AppSettings());
      return;
    }

    state = const AsyncValue.loading();
    try {
      final settings = await _repository.loadAppSettings(user.uid);
      state = AsyncValue.data(settings);
    } catch (e, st) {
      debugPrint('[SETTINGS] Failed to load settings: $e');
      state = AsyncValue.error(e, st);
      state = const AsyncValue.data(AppSettings());
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    final current = state.value ?? const AppSettings();
    final updated = current.copyWith(language: language);
    await _persist(updated, tag: 'language');
  }

  Future<void> setCurrency(AppCurrency currency) async {
    final current = state.value ?? const AppSettings();
    final updated = current.copyWith(currency: currency);
    await _persist(updated, tag: 'currency');
  }

  Future<void> _persist(AppSettings updated, {required String tag}) async {
    state = AsyncValue.data(updated);

    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await _repository.updateAppSettings(userId, updated);
    } catch (e, st) {
      debugPrint('[SETTINGS] Failed to update $tag: $e');
      state = AsyncValue.error(e, st);
      state = AsyncValue.data(updated);
    }
  }
}
