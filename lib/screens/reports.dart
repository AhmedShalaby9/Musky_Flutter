import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/reports_cubit.dart';
import '../core/money.dart';
import '../core/theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    required this.cubit,
    required this.onExpired,
  });
  final ReportsCubit cubit;
  final VoidCallback onExpired;
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
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

  int _t(Map<String, dynamic> data, String key) =>
      (data['totals'] is Map ? (data['totals'][key] as num?)?.toInt() ?? 0 : 0);

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ReportsCubit, ReportsState>(
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
                      'التقارير',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
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
                    label: Text(state.from != null
                        ? 'من: ${_fmt(state.from!)}'
                        : 'من تاريخ'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(false, state.to),
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(state.to != null
                        ? 'إلى: ${_fmt(state.to!)}'
                        : 'إلى تاريخ'),
                  ),
                  if (state.from != null || state.to != null)
                    TextButton.icon(
                      onPressed: () {
                        widget.cubit.setFrom(null);
                        widget.cubit.setTo(null);
                      },
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('الكل'),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: state.loading
                    ? const Center(child: CircularProgressIndicator())
                    : state.error != null
                        ? Center(
                            child: Text(state.error!,
                                style: const TextStyle(color: Colors.red)),
                          )
                        : _body(state.data),
              ),
            ],
          ),
        ),
      );

  Widget _body(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return const Center(
        child: Text('لا توجد بيانات.', style: TextStyle(color: muted)),
      );
    }
    final revenue = _t(data, 'revenue_minor');
    final returned = _t(data, 'returned_minor');
    final netRevenue = _t(data, 'net_revenue_minor');
    final cogs = _t(data, 'cogs_minor');
    final grossProfit = _t(data, 'gross_profit_minor');
    final purchases = _t(data, 'purchases_minor');
    final expenses = _t(data, 'expenses_minor');
    final netProfit = _t(data, 'net_profit_minor');

    final topSelling = _list(data, 'top_selling');
    final topProfit = _list(data, 'top_profit');
    final topLoss = _list(data, 'top_loss');
    final topClients = _list(data, 'top_clients');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Summary cards ──
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _card('إجمالي المبيعات', revenue, teal),
              _card('المرتجعات', returned, const Color(0xFF795548)),
              _card('صافي المبيعات', netRevenue, teal),
              _card('تكلفة البضاعة', cogs, const Color(0xFF536D8A)),
              _card('مجمل الربح', grossProfit,
                  grossProfit >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
              _card('المشتريات', purchases, const Color(0xFF536D8A)),
              _card('المصروفات', expenses, const Color(0xFFC62828)),
              _card('صافي الربح', netProfit,
                  netProfit >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
            ],
          ),
          const SizedBox(height: 32),

          // ── Top selling products ──
          if (topSelling.isNotEmpty) ...[
            Text('أكثر المنتجات مبيعاً',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _productTable(topSelling, showProfit: false),
            const SizedBox(height: 32),
          ],

          // ── Top profit products ──
          if (topProfit.isNotEmpty) ...[
            Text('أكثر المنتجات ربحاً',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _productTable(topProfit, showProfit: true),
            const SizedBox(height: 32),
          ],

          // ── Top loss products ──
          if (topLoss.isNotEmpty) ...[
            Text('المنتجات الخاسرة',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _productTable(topLoss, showProfit: true, loss: true),
            const SizedBox(height: 32),
          ],

          // ── Top clients ──
          if (topClients.isNotEmpty) ...[
            Text('أكثر العملاء شراءً',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _clientTable(topClients),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic> data, String key) =>
      (data[key] as List? ?? []).cast<Map<String, dynamic>>();

  Widget _card(String label, int minor, Color color) => Container(
    width: 200,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: muted, fontSize: 13)),
        const SizedBox(height: 8),
        Text(
          egp(minor),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
            fontFamily: 'monospace',
          ),
        ),
      ],
    ),
  );

  Widget _productTable(List<Map<String, dynamic>> products,
      {required bool showProfit, bool loss = false}) =>
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              const DataColumn(label: Text('المنتج')),
              const DataColumn(label: Text('الكود')),
              const DataColumn(label: Text('الكمية المباعة')),
              const DataColumn(label: Text('الإيرادات')),
              if (showProfit) ...[
                const DataColumn(label: Text('التكلفة')),
                DataColumn(label: Text(loss ? 'الخسارة' : 'الربح')),
              ],
            ],
            rows: [
              for (final p in products)
                DataRow(cells: [
                  DataCell(Text('${p['title']}')),
                  DataCell(Text('${p['code']}')),
                  DataCell(Text('${p['qty_sold']}')),
                  DataCell(Text(egp((p['revenue_minor'] as num?)?.toInt() ?? 0))),
                  if (showProfit) ...[
                    DataCell(Text(egp((p['cogs_minor'] as num?)?.toInt() ?? 0))),
                    DataCell(Text(
                      egp((p['profit_minor'] as num?)?.toInt() ?? 0),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: loss
                            ? const Color(0xFFC62828)
                            : const Color(0xFF2E7D32),
                      ),
                    )),
                  ],
                ]),
            ],
          ),
        ),
      );

  Widget _clientTable(List<Map<String, dynamic>> clients) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(12),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('العميل')),
          DataColumn(label: Text('عدد الفواتير')),
          DataColumn(label: Text('إجمالي المشتريات')),
          DataColumn(label: Text('المدفوع')),
        ],
        rows: [
          for (final c in clients)
            DataRow(cells: [
              DataCell(Text('${c['name']}')),
              DataCell(Text('${c['invoice_count']}')),
              DataCell(Text(egp((c['revenue_minor'] as num?)?.toInt() ?? 0))),
              DataCell(Text(egp((c['paid_minor'] as num?)?.toInt() ?? 0))),
            ]),
        ],
      ),
    ),
  );
}
