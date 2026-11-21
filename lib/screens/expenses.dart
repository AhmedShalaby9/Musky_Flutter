import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/expenses_cubit.dart';
import '../core/api.dart';
import '../core/money.dart';
import '../core/theme.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({
    super.key,
    required this.cubit,
    required this.onExpired,
  });
  final ExpensesCubit cubit;
  final VoidCallback onExpired;
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  @override
  void initState() {
    super.initState();
    widget.cubit.refresh();
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool isFrom, DateTime? current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: isFrom ? 'من تاريخ' : 'إلى تاريخ',
    );
    if (picked == null) return;
    if (isFrom) {
      widget.cubit.setFrom(picked);
    } else {
      widget.cubit.setTo(picked);
    }
  }

  Future<void> _addExpense() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ExpenseDialog(),
    );
    if (result == null || !mounted) return;
    await widget.cubit.addExpense(
      result['amount_minor'] as int,
      result['description'] as String,
      result['spent_at'] as String,
    );
  }

  Future<void> _deleteExpense(Map<String, dynamic> entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المصروف'),
        content: Text(
          'سيتم حذف "${entry['description']}" بمبلغ ${egp((entry['amount_minor'] as num?)?.toInt() ?? 0)} نهائياً.',
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
    await widget.cubit.deleteExpense((entry['id'] as num).toInt());
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ExpensesCubit, ExpensesState>(
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
                      'المصروفات',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _addExpense,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('إضافة مصروف'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: widget.cubit.refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(true, state.from),
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(state.from != null ? 'من: ${_fmt(state.from!)}' : 'من تاريخ'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(false, state.to),
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(state.to != null ? 'إلى: ${_fmt(state.to!)}' : 'إلى تاريخ'),
                  ),
                  if (state.from != null || state.to != null)
                    TextButton.icon(
                      onPressed: () {
                        widget.cubit.setFrom(null);
                        widget.cubit.setTo(null);
                      },
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('مسح الفلتر'),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: 260,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إجمالي المصروفات', style: TextStyle(color: muted)),
                    const SizedBox(height: 8),
                    Text(
                      egp(state.totalMinor),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFC62828),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
                        : _entriesList(state),
              ),
            ],
          ),
        ),
      );

  Widget _entriesList(ExpensesState state) {
    final entries = state.entries;
    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد مصروفات مسجلة.',
          style: TextStyle(color: muted),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final e = entries[i];
              final amount = (e['amount_minor'] as num?)?.toInt() ?? 0;
              final desc = e['description'] as String? ?? '';
              final date = e['spent_at'] as String? ?? '';
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
                      _field('التاريخ', date, ltr: true),
                      _field('الوصف', desc),
                      _field('المبلغ', egp(amount), emphasize: true, ltr: true),
                    ];
                    if (size.maxWidth < 500) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            runSpacing: 16,
                            children: fields
                                .map((f) => SizedBox(width: size.maxWidth, child: f))
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => _deleteExpense(e),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('حذف'),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        ...fields.map((f) => Expanded(child: f)),
                        IconButton(
                          tooltip: 'حذف',
                          onPressed: () => _deleteExpense(e),
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
        if (entries.length >= 50 || state.offset > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: state.offset > 0
                      ? () => widget.cubit.setPage(state.offset - 50)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                Text('صفحة ${state.offset ~/ 50 + 1}'),
                IconButton(
                  onPressed: entries.length >= 50
                      ? () => widget.cubit.setPage(state.offset + 50)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
              ],
            ),
          ),
      ],
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
                color: emphasize ? const Color(0xFFC62828) : ink,
              ),
            ),
          ],
        ),
      );
}

class _ExpenseDialog extends StatefulWidget {
  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  late final _date = TextEditingController(
    text: _fmtDate(DateTime.now()),
  );

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    _date.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_date.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'تاريخ المصروف',
    );
    if (picked != null) {
      setState(() => _date.text = _fmtDate(picked));
    }
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final minor = parseMoney(_amount.text);
    if (minor == null || minor <= 0) return;
    Navigator.pop(context, {
      'amount_minor': minor,
      'description': _desc.text.trim(),
      'spent_at': _date.text,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('إضافة مصروف'),
    content: SizedBox(
      width: 400,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ (ج.م)',
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
              controller: _desc,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'الوصف',
                counterText: '',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'أدخل وصف المصروف.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _date,
              readOnly: true,
              onTap: _pickDate,
              decoration: const InputDecoration(
                labelText: 'التاريخ',
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              validator: (v) {
                if (v == null || DateTime.tryParse(v) == null) {
                  return 'أدخل تاريخاً صحيحاً.';
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
