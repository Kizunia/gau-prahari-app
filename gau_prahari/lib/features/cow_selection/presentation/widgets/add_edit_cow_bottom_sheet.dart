import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gau_prahari/core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/cow.dart';
import '../controllers/cow_controller.dart';

/// Bottom sheet for:
///  - Adding a completely new cow (pass [cow] = null)
///  - Editing the name of an existing cow (pass [cow] with existing data,
///    [nameOnly] = true)
///  - Editing all fields of a user-added cow (pass [cow], [nameOnly] = false)
Future<void> showAddEditCowSheet(
  BuildContext context, {
  Cow? cow,
  bool nameOnly = false,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<CowController>(),
      child: _AddEditCowSheet(existingCow: cow, nameOnly: nameOnly),
    ),
  );
}

class _AddEditCowSheet extends StatefulWidget {
  final Cow? existingCow;
  final bool nameOnly;

  const _AddEditCowSheet({this.existingCow, this.nameOnly = false});

  @override
  State<_AddEditCowSheet> createState() => _AddEditCowSheetState();
}

class _AddEditCowSheetState extends State<_AddEditCowSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _saveError;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _idCtrl;
  late final TextEditingController _tagCtrl;
  late final TextEditingController _breedCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _lactationCtrl;

  bool get _isEditing => widget.existingCow != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existingCow;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _idCtrl = TextEditingController(text: c?.id ?? '');
    _tagCtrl = TextEditingController(text: c?.tagNumber ?? '');
    _breedCtrl = TextEditingController(text: c?.breed ?? '');
    _ageCtrl = TextEditingController(text: c != null ? '${c.ageYears}' : '');
    _lactationCtrl = TextEditingController(text: c?.lactationStage ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _tagCtrl.dispose();
    _breedCtrl.dispose();
    _ageCtrl.dispose();
    _lactationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });

    final controller = context.read<CowController>();
    String? error;

    if (_isEditing) {
      // Only update the name
      error = await controller.updateCowName(
        widget.existingCow!.id,
        _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      );
    } else {
      // Add a brand-new cow
      error = await controller.addCow(
        id: _idCtrl.text,
        tagNumber: _tagCtrl.text,
        breed: _breedCtrl.text,
        ageYears: int.tryParse(_ageCtrl.text) ?? 4,
        lactationStage: _lactationCtrl.text,
        name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      );
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveError = error;
    });

    if (error == null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final t = AppLocalizations.of(context);
    final title = _isEditing
        ? (widget.nameOnly ? t.translate('editName') : t.translate('editCow'))
        : t.translate('addCow');

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPad),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.pets_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Name field (always shown) ──────────────────────────────
              _SectionLabel(
                icon: Icons.label_rounded,
                label: t.translate('cowName'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration(
                  hint: t.translate('cowNameHint'),
                  prefixIcon: Icons.drive_file_rename_outline_rounded,
                ),
              ),

              // ── Extra fields only for adding a new cow ─────────────────
              if (!_isEditing) ...[
                const SizedBox(height: 16),
                _SectionLabel(icon: Icons.tag_rounded, label: t.translate('cowIdLabel')),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _idCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _inputDecoration(
                    hint: 'e.g., COW-105',
                    prefixIcon: Icons.numbers_rounded,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? t.translate('cowIdRequired') : null,
                ),
                const SizedBox(height: 16),
                _SectionLabel(
                    icon: Icons.nfc_rounded, label: t.translate('rfidTagLabel')),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _tagCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _inputDecoration(
                    hint: 'e.g., RFID-1234',
                    prefixIcon: Icons.nfc_rounded,
                  ),
                ),
                const SizedBox(height: 16),
                _SectionLabel(
                    icon: Icons.category_rounded, label: t.translate('breedLabel')),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _breedCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration(
                    hint: 'e.g., Gir, Sahiwal, Murrah Buffalo',
                    prefixIcon: Icons.pets_rounded,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(
                              icon: Icons.cake_rounded, label: t.translate('ageLabel')),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _ageCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration(
                              hint: '4',
                              prefixIcon: Icons.cake_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionLabel(
                    icon: Icons.water_drop_rounded,
                    label: t.translate('lactationStageLabel')),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _lactationCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    hint: 'e.g., Early Lactation (Day 42)',
                    prefixIcon: Icons.water_drop_rounded,
                  ),
                ),
              ],

              // ── Error banner ───────────────────────────────────────────
              if (_saveError != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _saveError!,
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── Action buttons ─────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(t.translate('cancel'),
                          style: const TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Icon(_isEditing ? Icons.check_rounded : Icons.add_rounded),
                      label: Text(_isEditing ? t.translate('saveName') : t.translate('addCow')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: AppColors.surfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.borderFocused, width: 1.5),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primaryAccent),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryAccent,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
