import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/household_member_model.dart';
import '../../providers/household_provider.dart';
import '../../providers/auth_provider.dart';

class MemberManagementScreen extends ConsumerWidget {
  const MemberManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('Please login')),
          );
        }

        final householdId = user.householdId;
        final isHead = user.isHead;

        if (householdId == null || householdId.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.backgroundLight,
            appBar: AppBar(
              title: const Text('Manage Members'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.home_outlined,
                    size: 80,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isHead ? 'No household yet' : 'Ask your household owner',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isHead
                        ? 'Create a household to invite members.'
                        : 'You need to join a household as a member.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (!isHead) {
          return Scaffold(
            backgroundColor: AppColors.backgroundLight,
            appBar: AppBar(
              title: const Text('Household Members'),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Only household heads can manage members. Please contact your household owner for changes.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final householdAsync = ref.watch(householdProvider(householdId));
        final membersAsync =
            ref.watch(allHouseholdMemberDetailsProvider(householdId));

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            title: const Text('Manage Members'),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_add),
                onPressed: () =>
                    _showInviteMemberDialog(context, ref, householdId),
              ),
            ],
          ),
          body: householdAsync.when(
            data: (household) {
              if (household == null) {
                return const Center(child: Text('Household not found'));
              }

              return membersAsync.when(
                data: (memberDetails) {
                  final pendingMembers = memberDetails
                      .where((d) => d.membership.status == MemberStatus.invited)
                      .toList();
                  final activeMembers = memberDetails
                      .where((d) => d.membership.status == MemberStatus.active)
                      .toList();

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Household Info Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                household.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Invite Code',
                                style: TextStyle(
                                  fontSize: 12,
                                  letterSpacing: 0.4,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    household.inviteCode,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(
                                          text: household.inviteCode));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('Invite code copied')),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _MemberCount(
                                count: activeMembers.length,
                                pendingCount: pendingMembers.length,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Pending Members Section
                      if (pendingMembers.isNotEmpty) ...[
                        Row(
                          children: [
                            const Text(
                              'Pending Invites',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${pendingMembers.length}',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...pendingMembers.map((detail) => _PendingMemberCard(
                              detail: detail,
                              householdId: householdId,
                              currentUserId: user.userId,
                            )),
                        const SizedBox(height: 16),
                      ],

                      // Active Members List
                      const Text(
                        'Active Members',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...activeMembers.map(
                        (detail) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: detail.isOwner
                                  ? AppColors.primary.withOpacity(0.2)
                                  : AppColors.secondary.withOpacity(0.2),
                              child: Text(
                                detail.initials,
                                style: TextStyle(
                                  color: detail.isOwner
                                      ? AppColors.primary
                                      : AppColors.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              detail.displayName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (detail.email.isNotEmpty)
                                  Text(
                                    detail.email,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                if (detail.email.isNotEmpty)
                                  const SizedBox(height: 4),
                                Chip(
                                  label: Text(detail.roleLabel),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  labelStyle: TextStyle(
                                    color: detail.isOwner
                                        ? AppColors.primary
                                        : AppColors.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  backgroundColor: detail.isOwner
                                      ? AppColors.primary.withOpacity(0.1)
                                      : AppColors.secondary.withOpacity(0.1),
                                ),
                              ],
                            ),
                            trailing: !detail.isOwner &&
                                    household.ownerUserId == user.userId
                                ? IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    color: Colors.red,
                                    onPressed: () => _confirmRemoveMember(
                                      context,
                                      ref,
                                      detail.membership.userId,
                                      householdId,
                                      user.userId,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) =>
          Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }
}

class _MemberCount extends StatelessWidget {
  final int count;
  final int pendingCount;

  const _MemberCount({required this.count, this.pendingCount = 0});

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? 'member' : 'members';
    final text = pendingCount > 0
        ? '$count $label, $pendingCount pending'
        : '$count $label';
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _PendingMemberCard extends ConsumerWidget {
  final HouseholdMemberDetail detail;
  final String householdId;
  final String currentUserId;

  const _PendingMemberCard({
    required this.detail,
    required this.householdId,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: Colors.orange.withOpacity(0.05),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withOpacity(0.2),
          child: Text(
            detail.initials,
            style: const TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          detail.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (detail.email.isNotEmpty)
              Text(
                detail.email,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            if (detail.email.isNotEmpty) const SizedBox(height: 4),
            const Chip(
              label: Text('Pending'),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelStyle: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              backgroundColor: Color(0xFFFFE0B2),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              color: Colors.green,
              tooltip: 'Approve',
              onPressed: () => _handleApproveMember(
                context,
                ref,
                detail.membership.userId,
                householdId,
                currentUserId,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              color: Colors.red,
              tooltip: 'Reject',
              onPressed: () => _handleRejectMember(
                context,
                ref,
                detail.membership.userId,
                householdId,
                currentUserId,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleApproveMember(
    BuildContext context,
    WidgetRef ref,
    String memberId,
    String householdId,
    String currentUserId,
  ) async {
    try {
      await ref.read(householdNotifierProvider.notifier).approveMember(
            householdId: householdId,
            userId: memberId,
            currentUserId: currentUserId,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member approved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _handleRejectMember(
    BuildContext context,
    WidgetRef ref,
    String memberId,
    String householdId,
    String currentUserId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Invitation'),
        content: const Text(
            'Are you sure you want to reject this invitation? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(householdNotifierProvider.notifier).rejectMember(
            householdId: householdId,
            userId: memberId,
            currentUserId: currentUserId,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation rejected')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

void _showInviteMemberDialog(
    BuildContext context, WidgetRef ref, String householdId) {
  final emailController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Invite Member'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'member@example.com',
            ),
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            final email = emailController.text.trim();
            if (email.isEmpty || !email.contains('@')) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a valid email')),
              );
              return;
            }

            try {
              await ref
                  .read(householdNotifierProvider.notifier)
                  .inviteMember(householdId, email);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invitation sent to $email')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
          },
          child: const Text('Send Invite'),
        ),
      ],
    ),
  );
}

void _confirmRemoveMember(
  BuildContext context,
  WidgetRef ref,
  String memberId,
  String householdId,
  String currentUserId,
) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remove Member'),
      content: const Text(
          'Are you sure you want to remove this member from the household?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            try {
              await ref.read(householdNotifierProvider.notifier).removeMember(
                    householdId: householdId,
                    userId: memberId,
                    currentUserId: currentUserId,
                  );
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Member removed'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
          },
          child: const Text('Remove', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}
