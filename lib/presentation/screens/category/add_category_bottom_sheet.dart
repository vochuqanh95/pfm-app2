import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/category_model.dart';
import '../../providers/category_provider.dart';

// MANUAL TEST CHECKLIST (Add Category)
// 1) Open Add Transaction -> Add category -> create personal expense -> appears immediately in picker.
// 2) As household head, create household income category -> visible to head in picker.
// 3) Member creates personal category -> only their picker shows it, head household categories remain.
// 4) Saving with empty name is blocked.

class AddCategoryBottomSheet extends ConsumerStatefulWidget {
  final CategoryType type;
  final String userId;
  final String? householdId;
  final bool canCreateHouseholdCategory;

  const AddCategoryBottomSheet({
    super.key,
    required this.type,
    required this.userId,
    required this.householdId,
    required this.canCreateHouseholdCategory,
  });

  @override
  ConsumerState<AddCategoryBottomSheet> createState() =>
      _AddCategoryBottomSheetState();
}

class _AddCategoryBottomSheetState
    extends ConsumerState<AddCategoryBottomSheet> {
  final _nameController = TextEditingController();
  CategoryScope _scope = CategoryScope.personal;
  int _selectedColorIndex = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.canCreateHouseholdCategory &&
        (widget.householdId != null && widget.householdId!.isNotEmpty)) {
      _scope = CategoryScope.household;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _categoryColors;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add ${widget.type == CategoryType.expense ? 'Expense' : 'Income'} Category',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _saving ? null : () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Category name',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 12),
          if (widget.canCreateHouseholdCategory) ...[
            const Text(
              'Scope',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Column(
              children: [
                RadioListTile<CategoryScope>(
                  title: const Text('Family category'),
                  subtitle: const Text('Visible to household members'),
                  value: CategoryScope.household,
                  groupValue: _scope,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _scope = value);
                    }
                  },
                ),
                RadioListTile<CategoryScope>(
                  title: const Text('My personal category'),
                  subtitle: const Text('Visible only to me'),
                  value: CategoryScope.personal,
                  groupValue: _scope,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _scope = value);
                    }
                  },
                ),
              ],
            ),
          ] else
            const Text(
              'Scope: Personal (household categories require head role)',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          const SizedBox(height: 12),
          const Text(
            'Color',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(colors.length, (index) {
              final color = colors[index];
              final selected = index == _selectedColorIndex;
              return GestureDetector(
                onTap: () => setState(() => _selectedColorIndex = index),
                child: CircleAvatar(
                  backgroundColor: color,
                  radius: selected ? 18 : 16,
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Category'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a category name')),
      );
      return;
    }

    if (_scope == CategoryScope.household &&
        (widget.householdId == null || widget.householdId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Join a household or choose Personal instead')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final category = CategoryModel(
        categoryId: '',
        name: name,
        type: widget.type,
        scope: _scope,
        userId: widget.userId,
        householdId:
            _scope == CategoryScope.household ? widget.householdId : null,
        iconName: widget.type == CategoryType.expense
            ? 'custom_expense'
            : 'custom_income',
        colorIndex: _selectedColorIndex,
        isSystem: false,
        archived: false,
      );

      final repo = ref.read(categoryRepositoryProvider);
      final id = await repo.createCustomCategory(category);

      if (mounted) {
        Navigator.pop(context, category.copyWith(categoryId: id));
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        final friendly = e.code == 'permission-denied'
            ? (_scope == CategoryScope.household
                ? 'You do not have permission to create household categories. Try a personal category instead.'
                : 'You do not have permission to create this category.')
            : 'Failed to save category: ${e.message ?? e.code}';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendly)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save category: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

const List<Color> _categoryColors = [
  AppColors.primary,
  AppColors.secondary,
  AppColors.warning,
  AppColors.info,
  AppColors.success,
  AppColors.error,
  AppColors.textSecondary,
];
