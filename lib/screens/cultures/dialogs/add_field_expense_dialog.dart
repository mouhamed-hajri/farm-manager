import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/expense.dart';
import '../../../providers/core_providers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/date_field.dart';
import '../../../widgets/photo_picker_widget.dart';

/// Compact picker + amount dialog for adding a field-level expense.
/// Description + photo appear or hide based on the selected category.
class AddFieldExpenseDialog extends ConsumerStatefulWidget {
  const AddFieldExpenseDialog({
    super.key,
    required this.fieldId,
  });

  final String fieldId;

  @override
  ConsumerState<AddFieldExpenseDialog> createState() =>
      _AddFieldExpenseDialogState();
}

class _AddFieldExpenseDialogState
    extends ConsumerState<AddFieldExpenseDialog> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = FieldExpenseCategory.workforce;
  DateTime _date = DateTime.now();
  String? _photoLocalPath;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount =
        double.tryParse(_amountCtrl.text.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Montant invalide');
      return;
    }
    if (FieldExpenseCategory.descriptionRequired(_category) &&
        _descCtrl.text.trim().isEmpty) {
      setState(() => _error = _category == FieldExpenseCategory.supplies
          ? 'Précisez ce que vous avez acheté'
          : 'Précisez ce qu\'est cette dépense');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;
      await ref.read(expenseRepositoryProvider).addExpense(Expense(
            id: '',
            userId: user.uid,
            scope: ExpenseScope.field,
            linkedFieldId: widget.fieldId,
            amount: amount,
            category: _category,
            date: _date.toIso8601String().substring(0, 10),
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            receiptPhotoLocalPath: _photoLocalPath,
            createdAt: '',
            updatedAt: '',
            syncStatus: 'pending',
          ));
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showDesc = FieldExpenseCategory.showDescription(_category);
    final showPhoto = FieldExpenseCategory.showPhoto(_category);
    return AlertDialog(
      title: Row(
        children: const [
          Text('💰 ', style: TextStyle(fontSize: 22)),
          Expanded(child: Text('Frais du champ')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: FieldExpenseCategory.all.map((c) {
                final selected = _category == c;
                return ChoiceChip(
                  label: Text(
                      '${FieldExpenseCategory.emoji(c)} ${FieldExpenseCategory.labelFr(c)}'),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = c),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            DateField(
              label: 'Date',
              initialDate: _date,
              lastDate: DateTime.now(),
              required: true,
              onChanged: (d) {
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Montant (TND) *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              onChanged: (_) => setState(() {}),
            ),

            // Description appears conditionally — label adapts to the category.
            if (showDesc) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                decoration: InputDecoration(
                  labelText:
                      FieldExpenseCategory.descriptionLabel(_category),
                  hintText: _category == FieldExpenseCategory.supplies
                      ? 'ex: Sac d\'engrais NPK 50kg'
                      : _category == FieldExpenseCategory.treatment
                          ? 'ex: Fongicide pour la cochenille'
                          : 'ex: Réparation du système d\'irrigation',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(
                    _category == FieldExpenseCategory.supplies
                        ? Icons.shopping_cart_outlined
                        : _category == FieldExpenseCategory.treatment
                            ? Icons.science_outlined
                            : Icons.notes,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],

            // Photo picker appears conditionally (receipts / product labels).
            if (showPhoto) ...[
              const SizedBox(height: 14),
              Text(
                _category == FieldExpenseCategory.supplies
                    ? 'Photo du reçu (optionnel)'
                    : 'Photo du produit (optionnel)',
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
              const SizedBox(height: 6),
              PhotoPickerWidget(
                localPath: _photoLocalPath,
                cloudUrl: null,
                onChanged: (p) => setState(() => _photoLocalPath = p),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style:
                      const TextStyle(color: AppColors.red, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
