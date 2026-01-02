import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/goal_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/household_provider.dart';

class AddGoalScreen extends ConsumerStatefulWidget {
  const AddGoalScreen({super.key});

  @override
  ConsumerState<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends ConsumerState<AddGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  DateTime? _deadline;
  bool _familyGoal = true;
  String? _memberUserId;
  String? _memberDisplayName;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authUserProvider);
    final householdAsync = ref.watch(currentUserHouseholdProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) =>
          const Scaffold(body: Center(child: Text('Unable to load user'))),
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text('Please sign in.')));
        }

        final householdId = householdAsync.maybeWhen(
          data: (h) => h?.householdId ?? user.householdId ?? '',
          orElse: () => user.householdId ?? '',
        );

        final membersAsync = ref.watch(
          householdMemberDetailsProvider(householdId),
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Add Goal'),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Goal name',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _targetController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Target amount',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      validator: (val) => double.tryParse(val ?? '') == null
                          ? 'Enter a valid amount'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_deadline == null
                          ? 'Pick deadline'
                          : 'Deadline: ${_deadline!.toLocal().toString().split(' ').first}'),
                      leading: const Icon(Icons.event),
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _deadline ?? now,
                          firstDate: now,
                          lastDate: DateTime(now.year + 5),
                        );
                        if (picked != null) {
                          setState(() => _deadline = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ToggleButtons(
                      isSelected: [_familyGoal, !_familyGoal],
                      onPressed: (index) {
                        setState(() {
                          _familyGoal = index == 0;
                          if (_familyGoal) {
                            _memberUserId = null;
                            _memberDisplayName = null;
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Family goal'),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Member goal'),
                        ),
                      ],
                    ),
                    if (!_familyGoal)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: membersAsync.when(
                          loading: () => const CircularProgressIndicator(),
                          error: (_, __) =>
                              const Text('Unable to load members'),
                          data: (members) {
                            if (members.isEmpty) {
                              return const Text('No members available');
                            }
                            if (_memberUserId == null && members.isNotEmpty) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() {
                                    _memberUserId =
                                        members.first.membership.userId;
                                    _memberDisplayName = members.first.displayName;
                                  });
                                }
                              });
                            }
                            return DropdownButtonFormField<String>(
                              value: _memberUserId,
                              decoration: const InputDecoration(
                                  labelText: 'Assign to member'),
                              items: members
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m.membership.userId,
                                      child: Text('${m.displayName} (${m.roleLabel})'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                final selectedMember = members.firstWhere(
                                  (m) => m.membership.userId == val,
                                );
                                setState(() {
                                  _memberUserId = val;
                                  _memberDisplayName = selectedMember.displayName;
                                });
                              },
                              validator: (val) {
                                if (!_familyGoal &&
                                    (val == null || val.isEmpty)) {
                                  return 'Select a member';
                                }
                                return null;
                              },
                            );
                          },
                        ),
                      ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving
                            ? null
                            : () => _saveGoal(
                                  userId: user.userId,
                                  householdId: householdId,
                                  isHead: user.isHead,
                                ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save Goal'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveGoal({
    required String userId,
    required String householdId,
    required bool isHead,
  }) async {
    if (!_formKey.currentState!.validate()) return;
    if (householdId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join or create a household first.')),
      );
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final target = double.tryParse(_targetController.text) ?? 0;
    final assignedUser = _familyGoal ? null : _memberUserId;
    final goal = GoalModel(
      goalId: '',
      userId: assignedUser,
      householdId: householdId,
      name: _nameController.text.trim(),
      targetAmount: target,
      savedAmount: 0,
      deadline: _deadline,
      scope: _familyGoal ? 'family' : 'personal',
      createdAt: now,
      updatedAt: now,
      assignedUserDisplayName: _familyGoal ? null : _memberDisplayName,
    );

    try {
      final notifier = ref.read(goalNotifierProvider.notifier);
      await notifier.createGoal(goal);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal saved')),
        );
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save goal')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
