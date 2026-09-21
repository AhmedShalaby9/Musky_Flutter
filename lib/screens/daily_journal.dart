import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/journal_cubit.dart';
import '../core/money.dart';
import '../core/theme.dart';

class DailyJournalScreen extends StatefulWidget {
  const DailyJournalScreen({
    super.key,
    required this.cubit,
    required this.onExpired,
  });
  final JournalCubit cubit;
  final VoidCallback onExpired;
  @override
  State<DailyJournalScreen> createState() => _DailyJournalScreenState();
}

class _DailyJournalScreenState extends State<DailyJournalScreen> {
  @override
  void initState() {
    super.initState();
    widget.cubit.setDate(DateTime.now());
  }

  //push
  String _dateText(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'اختر اليوم',
    );
    if (picked != null) widget.cubit.setDate(picked);
  }

  int _total(Map<String, dynamic> data, String key) =>
      (data['totals'] is Map ? (data['totals'][key] as int? ?? 0) : 0);

  String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final period = value.hour < 12 ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _deleteReceipt(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الدفعة نهائياً'),
        content: Text(
          'سيتم حذف دفعة ${row['client_name'] ?? ''} من دفتر اليومية وكشف حساب العميل نهائياً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.cubit.deleteReceipt(
      clientId: (row['client_id'] as num).toInt(),
      receiptId: (row['id'] as num).toInt(),
    );
  }

  Widget _journalField(
    String label,
    String value, {
    bool emphasize = false,
    bool ltr = false,
  }) => Padding(
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

  Widget _structuredRows(List<Map<String, dynamic>> rows) => ListView.separated(
    itemCount: rows.length,
    separatorBuilder: (context, index) => const SizedBox(height: 10),
    itemBuilder: (_, i) {
      final p = rows[i];
      final paid = DateTime.tryParse(p['paid_at'] as String? ?? '')?.toLocal();
      final time = paid == null ? '—' : _time(paid);
      final invoice = p['invoice_number'] == null
          ? '—'
          : '${invoiceTypeLabel(p['document_type'])} INV-${(p['invoice_number'] as int).toString().padLeft(6, '0')}';
      final notes = p['notes'] as String? ?? '';
      final receipt = p['kind'] == 'client_receipt';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
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
              _journalField('العميل', p['client_name'] as String? ?? '—'),
              _journalField('الوقت', time, ltr: true),
              _journalField('الفاتورة', invoice, ltr: true),
              _journalField(
                'طريقة الدفع',
                p['method'] == 'online' ? 'إلكتروني' : 'نقدي',
              ),
              _journalField(
                'المبلغ',
                egp(p['amount_minor'] as int? ?? 0),
                emphasize: true,
                ltr: true,
              ),
              _journalField('ملاحظات', notes.isEmpty ? '—' : notes),
            ];
            final deleteButton = IconButton(
              tooltip: 'حذف الدفعة نهائياً',
              onPressed: receipt ? () => _deleteReceipt(p) : null,
              icon: Icon(
                Icons.delete_outline,
                color: receipt ? Colors.red : line,
              ),
            );
            if (size.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    runSpacing: 16,
                    children: fields
                        .map(
                          (field) => SizedBox(
                            width: size.maxWidth < 480
                                ? size.maxWidth
                                : size.maxWidth / 2,
                            child: field,
                          ),
                        )
                        .toList(),
                  ),
                  if (receipt) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _deleteReceipt(p),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('حذف نهائي'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                ],
              );
            }
            return Row(
              children: [
                ...fields.map((field) => Expanded(child: field)),
                deleteButton,
              ],
            );
          },
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<JournalCubit, JournalState>(
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
                      'دفتر اليومية',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(state.date),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(_dateText(state.date)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: widget.cubit.refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _summary(state, 'إجمالي المقبوضات', 'all_minor', teal),
                  _summary(
                    state,
                    'نقدي',
                    'cash_minor',
                    const Color(0xFF527A54),
                  ),
                  _summary(
                    state,
                    'إلكتروني',
                    'online_minor',
                    const Color(0xFF536D8A),
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
                    : _rows(state.data),
              ),
            ],
          ),
        ),
      );

  Widget _summary(JournalState state, String label, String key, Color color) =>
      Container(
        width: 210,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: muted)),
            const SizedBox(height: 8),
            Text(
              egp(_total(state.data, key)),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      );

  Widget _rows(Map<String, dynamic> data) {
    final rows = (data['data'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد دفعات مسجلة في هذا اليوم.',
          style: TextStyle(color: muted),
        ),
      );
    }
    return _structuredRows(rows);
  }
}
