import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/china_cubit.dart';
import '../core/api.dart';
import '../core/money.dart';
import '../core/theme.dart';

class ChinaBalanceScreen extends StatefulWidget {
  const ChinaBalanceScreen({
    super.key,
    required this.cubit,
    required this.onExpired,
  });
  final ChinaCubit cubit;
  final VoidCallback onExpired;
  @override
  State<ChinaBalanceScreen> createState() => _ChinaBalanceScreenState();
}

class _ChinaBalanceScreenState extends State<ChinaBalanceScreen> {
  @override
  void initState() {
    super.initState();
    widget.cubit.refresh();
  }

  String _kindLabel(String kind) => switch (kind) {
    'opening' => 'رصيد افتتاحي',
    'purchase' => 'بضاعة',
    'payment' => 'دفعة',
    'adjustment' => 'تعديل',
    _ => kind,
  };

  String _dateText(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _addEntry(String kind, String title) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EntryDialog(title: title, kind: kind),
    );
    if (result == null || !mounted) return;
    await widget.cubit.addEntry(
      kind,
      result['amount_minor'] as int,
      result['notes'] as String,
    );
  }

  Future<void> _deleteEntry(Map<String, dynamic> entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الحركة'),
        content: Text(
          'سيتم حذف ${_kindLabel(entry['kind'] as String? ?? '')} بمبلغ ${cny((entry['amount_minor'] as num?)?.toInt() ?? 0)} نهائياً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.cubit.deleteEntry((entry['id'] as num).toInt());
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ChinaCubit, ChinaState>(
        bloc: widget.cubit,
        listener: (context, state) {
          if (state.expired) widget.onExpired();
        },
        builder: (context, state) => Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'رصيد الصين',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: widget.cubit.refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                width: 280,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('المبلغ المستحق', style: TextStyle(color: muted)),
                    const SizedBox(height: 8),
                    Text(
                      cny(state.balanceMinor),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: teal,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (!state.hasOpening)
                    FilledButton.icon(
                      onPressed: () => _addEntry('opening', 'رصيد افتتاحي'),
                      icon: const Icon(Icons.account_balance_outlined, size: 18),
                      label: const Text('رصيد افتتاحي'),
                    ),
                  FilledButton.icon(
                    onPressed: () => _addEntry('purchase', 'بضاعة جديدة'),
                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: const Text('بضاعة'),
                  ),
                  FilledButton.icon(
                    onPressed: state.balanceMinor > 0
                        ? () => _addEntry('payment', 'دفعة')
                        : null,
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text('دفعة'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _addEntry('adjustment', 'تعديل'),
                    icon: const Icon(Icons.edit_note_outlined, size: 18),
                    label: const Text('تعديل'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: state.loading
                    ? const Center(child: CircularProgressIndicator())
                    : state.error != null
                        ? Center(
                            child: Text(
                              state.error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          )
                        : _entriesList(state.entries),
              ),
            ],
          ),
        ),
      );

  Widget _entriesList(List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد حركات مسجلة.',
          style: TextStyle(color: muted),
        ),
      );
    }
    // Show newest first in the list.
    final reversed = entries.reversed.toList();
    return ListView.separated(
      itemCount: reversed.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final e = reversed[i];
        final kind = e['kind'] as String? ?? '';
        final isPayment = kind == 'payment';
        final amount = (e['amount_minor'] as num?)?.toInt() ?? 0;
        final notes = e['notes'] as String? ?? '';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: line),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, size) {
              final fields = [
                _field('التاريخ', _dateText(e['created_at'] as String?), ltr: true),
                _field('النوع', _kindLabel(kind)),
                _field(
                  'المبلغ',
                  '${isPayment ? '-' : '+'}${cny(amount)}',
                  emphasize: true,
                  ltr: true,
                ),
                _field('ملاحظات', notes.isEmpty ? '—' : notes),
              ];
              final isOpening = kind == 'opening';
              if (size.maxWidth < 600) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      runSpacing: 16,
                      children: fields
                          .map((f) => SizedBox(
                                width: size.maxWidth < 400
                                    ? size.maxWidth
                                    : size.maxWidth / 2,
                                child: f,
                              ))
                          .toList(),
                    ),
                    if (!isOpening || entries.length == 1) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _deleteEntry(e),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('حذف'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  ...fields.map((f) => Expanded(child: f)),
                  IconButton(
                    tooltip: 'حذف',
                    onPressed: (!isOpening || entries.length == 1)
                        ? () => _deleteEntry(e)
                        : null,
                    icon: Icon(
                      Icons.delete_outline,
                      color: (!isOpening || entries.length == 1)
                          ? Colors.red
                          : line,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _field(String label, String value,
      {bool emphasize = false, bool ltr = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: muted, fontSize: 11)),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textDirection: ltr ? TextDirection.ltr : null,
              style: TextStyle(
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                color: emphasize ? teal : ink,
              ),
            ),
          ],
        ),
      );
}

class _EntryDialog extends StatefulWidget {
  const _EntryDialog({required this.title, required this.kind});
  final String title;
  final String kind;
  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final minor = parseMoney(_amount.text);
    if (minor == null || minor <= 0) return;
    Navigator.pop(context, {
      'amount_minor': minor,
      'notes': _notes.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 380,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ (يوان)',
                hintText: '0.00',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'أدخل المبلغ.';
                final minor = parseMoney(v);
                if (minor == null || minor <= 0) return 'مبلغ غير صالح.';
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notes,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: _submit,
        child: const Text('حفظ'),
      ),
    ],
  );
}
