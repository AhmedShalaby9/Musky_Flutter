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
                  _summary(
                    state,
                    'إجمالي المقبوضات',
                    'all_minor',
                    teal,
                  ),
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

  Widget _summary(
    JournalState state,
    String label,
    String key,
    Color color,
  ) =>
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
    final rows =
        (data['data'] as List? ?? const []).cast<Map<String, dynamic>>();
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد دفعات مسجلة في هذا اليوم.',
          style: TextStyle(color: muted),
        ),
      );
    }
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = rows[i];
        final paid =
            DateTime.tryParse(p['paid_at'] as String? ?? '')?.toLocal();
        final time = paid == null
            ? '—'
            : '${paid.hour.toString().padLeft(2, '0')}:${paid.minute.toString().padLeft(2, '0')}';
        final invoice = p['invoice_number'] == null
            ? '—'
            : 'INV-${(p['invoice_number'] as int).toString().padLeft(6, '0')}';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 65,
                child: Text(time, textDirection: TextDirection.ltr),
              ),
              Expanded(
                child: Text(
                  p['client_name'] as String? ?? '—',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 125,
                child: Text(invoice, textDirection: TextDirection.ltr),
              ),
              SizedBox(
                width: 90,
                child: Text(
                  p['method'] == 'online' ? 'إلكتروني' : 'نقدي',
                ),
              ),
              SizedBox(
                width: 125,
                child: Text(
                  egp(p['amount_minor'] as int? ?? 0),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: Text(
                  p['notes'] as String? ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
