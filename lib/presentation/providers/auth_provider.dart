import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/two_factor_service.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/models/user_model.dart';

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// Two Factor Service Provider
final twoFactorServiceProvider = Provider<TwoFactorService>((ref) => MockTwoFactorService());

// User Repository Provider
final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepository());

// Current Firebase User Stream
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Combined auth + Firestore user provider
final authUserProvider = StreamProvider<UserModel?>((ref) {
  final authService = ref.watch(authServiceProvider);
  final userRepository = ref.watch(userRepositoryProvider);

  final controller = StreamController<UserModel?>.broadcast();
  StreamSubscription<User?>? authSubscription;
  StreamSubscription<UserModel?>? userDocSubscription;
  bool isCreatingUserDoc = false;

  void safeAdd(UserModel? user) {
    if (!controller.isClosed) {
      controller.add(user);
    }
  }

  void safeAddError(Object error, [StackTrace? stackTrace]) {
    if (!controller.isClosed) {
      controller.addError(error, stackTrace);
    }
  }

  void emitUser(User? firebaseUser) {
    userDocSubscription?.cancel();
    isCreatingUserDoc = false;

    if (firebaseUser == null) {
      safeAdd(null);
      return;
    }

    userDocSubscription = userRepository.getUserStream(firebaseUser.uid).listen(
      (userModel) {
        if (userModel != null) {
          safeAdd(userModel);
          return;
        }

        // Try to get a meaningful name from displayName or email
        String fallbackName = 'Member';
        if (firebaseUser.displayName != null && firebaseUser.displayName!.trim().isNotEmpty) {
          fallbackName = firebaseUser.displayName!.trim();
        } else if (firebaseUser.email != null && firebaseUser.email!.isNotEmpty) {
          final email = firebaseUser.email!;
          if (email.contains('@')) {
            final localPart = email.split('@').first;
            if (localPart.isNotEmpty) {
              // Capitalize first letter
              fallbackName = localPart.substring(0, 1).toUpperCase() + localPart.substring(1);
            }
          }
        }

        final now = DateTime.now();
        final newUser = UserModel(
          userId: firebaseUser.uid,
          name: fallbackName,
          email: firebaseUser.email ?? '',
          role: UserRoles.member,
          createdAt: now,
          updatedAt: now,
        );

        if (isCreatingUserDoc) {
          return;
        }

        isCreatingUserDoc = true;

        userRepository.createUser(newUser).then((_) {
          safeAdd(newUser);
        }).whenComplete(() {
          isCreatingUserDoc = false;
        });
      },
      onError: safeAddError,
    );
  }

  authSubscription = authService.authStateChanges.listen(
    emitUser,
    onError: safeAddError,
  );

  ref.onDispose(() async {
    await userDocSubscription?.cancel();
    await authSubscription?.cancel();
    await controller.close();
  });

  return controller.stream;
});

// Auth State Notifier
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final AuthService _authService;
  final UserRepository _userRepository;

  AuthNotifier(this._ref, this._authService, this._userRepository) : super(const AsyncValue.data(null));

  void _refreshAuthState() {
    _ref.invalidate(authStateProvider);
    _ref.invalidate(authUserProvider);
  }

  Future<UserModel?> signInWithEmailPassword(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final credentials = await _authService.signInWithEmailPassword(email: email, password: password);
      final firebaseUser = credentials.user;
      if (firebaseUser != null) {
        // Derive name from displayName or email local part
        String derivedName = 'Member';
        if (firebaseUser.displayName != null && firebaseUser.displayName!.trim().isNotEmpty) {
          derivedName = firebaseUser.displayName!.trim();
        } else if (email.contains('@')) {
          final localPart = email.split('@').first;
          if (localPart.isNotEmpty) {
            derivedName = localPart.substring(0, 1).toUpperCase() + localPart.substring(1);
          }
        }

        await _userRepository.ensureUserDocument(
          userId: firebaseUser.uid,
          name: derivedName,
          email: firebaseUser.email ?? email,
          role: UserRoles.member,
        );

        // Get user document to check 2FA status
        final userModel = await _userRepository.getUser(firebaseUser.uid);
        _refreshAuthState();
        state = const AsyncValue.data(null);
        return userModel;
      }
      _refreshAuthState();
      state = const AsyncValue.data(null);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    state = const AsyncValue.loading();
    try {
      final userCredential = await _authService.signUpWithEmailPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        await _userRepository.ensureUserDocument(
          userId: firebaseUser.uid,
          name: name,
          email: firebaseUser.email ?? email,
          role: role,
        );
      }
      _refreshAuthState();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final userCredential = await _authService.signInWithGoogle();
      final firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        await _userRepository.ensureUserDocument(
          userId: firebaseUser.uid,
          name: firebaseUser.displayName ?? firebaseUser.email ?? 'User',
          email: firebaseUser.email ?? '',
          role: UserRoles.head,
        );
      }
      _refreshAuthState();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    state = const AsyncValue.loading();
    try {
      await _authService.sendPasswordResetEmail(email);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _authService.signOut();
      _refreshAuthState();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    state = const AsyncValue.loading();
    try {
      final userId = _authService.currentUser?.uid;
      if (userId != null) {
        await _userRepository.deleteUser(userId);
        await _authService.deleteAccount();
      }
      _refreshAuthState();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

// Auth Notifier Provider
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  final authService = ref.watch(authServiceProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  return AuthNotifier(ref, authService, userRepository);
});

// Check if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    data: (user) => user != null,
    orElse: () => false,
  );
});
