/*
MANUAL TEST – LANGUAGE & CURRENCY

1. Default behavior
   - Fresh install, create new head user.
   - Open Settings → Language, Currency.
   - Verify defaults: English, US Dollar.
   - Check Home / Wallet / Transactions amounts show "$" with 2 decimals.

2. Change currency to VND
   - In Settings → Currency, select "Vietnamese Dong".
   - Verify:
     - Net Worth, Wallet cards, Transactions list show "₫" and no decimals.
     - CSV export includes VND amounts and currency_code = VND.
   - Logout, login again:
     - Currency still VND for same user.

3. Change language to Vietnamese
   - In Settings → Language, select "Tiếng Việt".
   - Verify:
     - Settings labels show in Vietnamese.
     - Bottom navigation labels changed if wired.
   - Kill app, relaunch:
     - Language persists (still Vietnamese).

4. Multi-user behavior
   - User A: set language = Vietnamese, currency = VND.
   - User B: set language = English, currency = USD.
   - Switch between both accounts:
     - Each user sees their own language & currency.

5. Regression checks
   - Create/edit transactions, debts, budgets after changing language/currency.
   - Net worth & reports still compute correctly (only formatting changes).
   - No crashes in logs related to AppSettings or localization.
*/
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance_management/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/password_validator.dart';
import '../../../core/enums/app_currency.dart';
import '../../../core/enums/app_language.dart';
import '../../../core/models/app_settings.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/auth_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _notificationsEnabled;
  bool? _twoFactorEnabled;
  bool _signingOut = false;
  bool _updatingTwoFactor = false;

  Future<void> _handleTwoFactorToggle(bool value, String userId) async {
    setState(() => _updatingTwoFactor = true);

    try {
      final userRepository = ref.read(userRepositoryProvider);
      await userRepository.updateTwoFactorEnabled(
        userId: userId,
        enabled: value,
      );

      if (!mounted) return;

      setState(() => _twoFactorEnabled = value);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Two-factor authentication enabled'
                : 'Two-factor authentication disabled',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update 2FA settings: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingTwoFactor = false);
      }
    }
  }

  String _languageLabel(AppLanguage language, AppLocalizations l10n) {
    if (language == AppLanguage.vietnamese) {
      return l10n.languageVietnamese;
    }
    return l10n.languageEnglish;
  }

  String _currencyLabel(AppCurrency currency, AppLocalizations l10n) {
    if (currency == AppCurrency.vnd) {
      return l10n.currencyVnd;
    }
    return l10n.currencyUsd;
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPasswordController,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your current password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      helperText: kPasswordHint,
                      helperMaxLines: 2,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                      ),
                    ),
                    validator: (value) => validatePassword(value ?? ''),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your new password';
                      }
                      if (value != newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setDialogState(() => isLoading = true);

                      try {
                        await ref.read(authNotifierProvider.notifier).changePassword(
                              currentPassword: currentPasswordController.text,
                              newPassword: newPasswordController.text,
                            );

                        if (!mounted) return;
                        Navigator.pop(dialogContext);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Password changed successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              e is AuthFailure ? e.message : 'Failed to change password',
                            ),
                          ),
                        );
                      } finally {
                        if (mounted) {
                          setDialogState(() => isLoading = false);
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Change Password'),
            ),
          ],
        ),
      ),
    );

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sign out',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) {
      return;
    }

    setState(() => _signingOut = true);
    try {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not sign out. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _signingOut = false);
      }
    }
  }

  Future<void> _showLanguageSheet(
    BuildContext context,
    AppLanguage current,
    AppLocalizations l10n,
  ) async {
    final options = <AppLanguage, String>{
      AppLanguage.english: l10n.languageEnglish,
      AppLanguage.vietnamese: l10n.languageVietnamese,
    };

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                l10n.chooseLanguage,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...options.entries.map(
              (entry) => ListTile(
                leading: Icon(
                  entry.key == current ? Icons.check_circle : Icons.circle_outlined,
                  color: entry.key == current ? AppColors.primary : AppColors.textSecondary,
                ),
                title: Text(entry.value),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await ref.read(appSettingsProvider.notifier).setLanguage(entry.key);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.languageUpdatedRestartHint)),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _showCurrencySheet(
    BuildContext context,
    AppCurrency current,
    AppLocalizations l10n,
  ) async {
    final options = <AppCurrency, String>{
      AppCurrency.usd: l10n.currencyUsd,
      AppCurrency.vnd: l10n.currencyVnd,
    };

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                l10n.chooseCurrency,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...options.entries.map(
              (entry) => ListTile(
                leading: Icon(
                  entry.key == current ? Icons.check_circle : Icons.circle_outlined,
                  color: entry.key == current ? AppColors.primary : AppColors.textSecondary,
                ),
                title: Text(entry.value),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await ref.read(appSettingsProvider.notifier).setCurrency(entry.key);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.currencyUpdated)),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userAsync = ref.watch(authUserProvider);
    final settingsAsync = ref.watch(appSettingsProvider);
    final settings = settingsAsync.valueOrNull ?? const AppSettings();

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Text(
            'Unable to load settings',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
      data: (user) {
        final displayName = (user?.name.isNotEmpty ?? false) ? user!.name : 'Fintrack Member';
        final email = user?.email ?? '';
        final userId = user?.userId ?? '';
        final roleLabel = (user?.role ?? UserRoles.member) == UserRoles.head ? 'Head' : 'Member';
        final isHead = user?.isHead ?? false;
        final notificationsEnabled = _notificationsEnabled ?? true;
        final twoFactorEnabled = _twoFactorEnabled ?? user?.twoFactorEnabled ?? false;

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            title: Text(l10n.settingsTitle),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'F',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Chip(
                                label: Text(roleLabel),
                                backgroundColor: isHead
                                    ? AppColors.primary.withOpacity(0.15)
                                    : AppColors.secondary.withOpacity(0.15),
                                labelStyle: TextStyle(
                                  color: isHead ? AppColors.primary : AppColors.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _SectionHeader(title: 'Preferences'),
              _SettingsTile(
                icon: Icons.language,
                title: l10n.settingsLanguage,
                subtitle: _languageLabel(settings.language, l10n),
                onTap: () => _showLanguageSheet(context, settings.language, l10n),
              ),
              _SettingsTile(
                icon: Icons.attach_money,
                title: l10n.settingsCurrency,
                subtitle: _currencyLabel(settings.currency, l10n),
                onTap: () => _showCurrencySheet(context, settings.currency, l10n),
              ),
              const SizedBox(height: 24),
              _SectionHeader(title: 'Security & Notifications'),
              _SettingsTile(
                icon: Icons.lock_reset,
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: () => _showChangePasswordDialog(context),
              ),
              _SettingsTile(
                icon: Icons.security,
                title: 'Two-Factor Authentication',
                subtitle: 'Add extra verification to your account',
                trailing: Switch(
                  value: twoFactorEnabled,
                  onChanged: _updatingTwoFactor
                      ? null
                      : (value) => _handleTwoFactorToggle(value, userId),
                ),
              ),
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Alerts for budgets, bills, and approvals',
                trailing: Switch(
                  value: notificationsEnabled,
                  onChanged: (value) => setState(() => _notificationsEnabled = value),
                ),
              ),
              const SizedBox(height: 24),
              if (isHead) ...[
                _SectionHeader(title: 'Household'),
                _SettingsTile(
                  icon: Icons.group_outlined,
                  title: 'Manage Members',
                  subtitle: 'Invite or manage family members',
                  onTap: () => context.push('/member-management'),
                ),
                const SizedBox(height: 24),
              ] else if (((user?.householdId) ?? '').isEmpty) ...[
                _SectionHeader(title: 'Household'),
                _SettingsTile(
                  icon: Icons.group_add_outlined,
                  title: 'Join a Household',
                  subtitle: 'Enter invite code shared by your family',
                  onTap: () => context.push('/join-household'),
                ),
                const SizedBox(height: 24),
              ],
              _SectionHeader(title: 'Support'),
              _SettingsTile(
                icon: Icons.help_outline,
                title: 'Help & Support',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'About Fintrack',
                onTap: () {},
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _signingOut ? null : () => _handleSignOut(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _signingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.logout),
                label: Text(_signingOut ? 'Signing out...' : 'Sign out'),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              )
            : null,
        trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
        onTap: onTap,
      ),
    );
  }
}
