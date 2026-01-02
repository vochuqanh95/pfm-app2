import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/household_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/household_provider.dart';

class JoinHouseholdScreen extends ConsumerStatefulWidget {
  const JoinHouseholdScreen({super.key});

  @override
  ConsumerState<JoinHouseholdScreen> createState() => _JoinHouseholdScreenState();
}

class _JoinHouseholdScreenState extends ConsumerState<JoinHouseholdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isJoining = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinHousehold() async {
    if (!_formKey.currentState!.validate()) return;

    final authUserAsync = ref.read(authUserProvider);
    if (authUserAsync.isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Still setting up your account. Please try again in a moment.')),
      );
      return;
    }

    final authUser = authUserAsync.valueOrNull;
    final firebaseUser = ref.read(authServiceProvider).currentUser;

    if (firebaseUser == null || authUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to join a household.')),
      );
      return;
    }

    if (authUser.householdId != null && authUser.householdId!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already belong to a household.')),
      );
      return;
    }

    setState(() => _isJoining = true);
    final code = _codeController.text.trim().toUpperCase();
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Use new provider method with validations
      final household = await ref.read(householdNotifierProvider.notifier).joinCurrentUserToHousehold(
        inviteCode: code,
        userId: firebaseUser.uid,
      );

      // Refresh providers to update UI
      ref.invalidate(authUserProvider);
      ref.invalidate(currentUserHouseholdProvider);

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text('Successfully joined ${household.name}!'),
          backgroundColor: Colors.green,
        ),
      );

      context.go('/member-home');
    } on HouseholdJoinFailure catch (e) {
      // Handle specific join errors
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: e.code == 'already_member' ? Colors.orange : Colors.red,
          ),
        );
      }
    } catch (e) {
      // Handle unexpected errors
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to join household: ${e.toString().replaceFirst('Exception: ', '')}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Join Household'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.group_add_outlined,
                  size: 72,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enter the invite code your household owner shared with you.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Invite Code',
                    hintText: 'E.g. ABC123',
                    helperText: '6-8 characters (letters and numbers only)',
                    prefixIcon: Icon(Icons.key),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 8,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the invite code';
                    }
                    final trimmed = value.trim().toUpperCase();
                    if (!RegExp(r'^[A-Z0-9]{6,8}$').hasMatch(trimmed)) {
                      return 'Invalid format. Use 6-8 letters/numbers only';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isJoining ? null : _joinHousehold,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isJoining
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Join Household'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    final user = ref.read(authUserProvider).valueOrNull;
                    final destination = (user?.isMember ?? true) ? '/member-home' : '/home';
                    context.go(destination);
                  },
                  child: const Text('Skip for now'),
                ),
                const SizedBox(height: 8),
                Text(
                  'You can join a household later from Settings.',
                  style: TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
