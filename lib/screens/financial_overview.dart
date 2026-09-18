import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/overview_cubit.dart';
import '../core/api.dart';
import '../core/money.dart';
import '../core/theme.dart';
import 'client_detail.dart';

class FinancialOverview extends StatefulWidget {
  const FinancialOverview({
    super.key,
    required this.cubit,
    required this.api,
    required this.tenantId,
    required this.name,
    required this.onExpired,
    required this.onInvoices,
    required this.onClients,
    required this.onProducts,
    required this.onJournal,
  });
  final OverviewCubit cubit;
  final MuskyApi api;
  final int tenantId;
  final String name;
  final VoidCallback onExpired, onInvoices, onClients, onProducts, onJournal;
  @override
  State<FinancialOverview> createState() => _FinancialOverviewState();
}

class _FinancialOverviewState extends State<FinancialOverview> {
  @override
  void initState() {
    super.initState();
    widget.cubit.loadIfNeeded();
  }

  Widget _quickAction(
    String label,
    IconData icon,
    VoidCallback onPressed, {
    bool primary = false,
  }) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: primary ? ink : Colors.white,
      backgroundColor: primary
          ? const Color(0xFFDAEDCE)
          : Colors.white.withValues(alpha: .08),
      side: BorderSide(
        color: primary ? Colors.transparent : const Color(0xFF55766D),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
  );

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<OverviewCubit, OverviewState>(
    bloc: widget.cubit,
    listener: (context, state) {
      if (state.expired) widget.onExpired();
    },
    builder: (context, state) => SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.circular(18),
            ),
            child: LayoutBuilder(
              builder: (context, size) => Wrap(
                spacing: 24,
                runSpacing: 20,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: size.maxWidth > 700
                        ? size.maxWidth * .43
                        : size.maxWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'أهلاً، ${widget.name}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 9),
                        const Text(
                          'ابدأ يومك من هنا: راجع الحسابات، سجّل فاتورة، أو تابع حركة الأصناف.',
                          style: TextStyle(
                            color: Color(0xFFB6C9C1),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _quickAction(
                        'فاتورة جديدة',
                        Icons.receipt_long_outlined,
                        widget.onInvoices,
                        primary: true,
                      ),
                      _quickAction(
                        'العملاء',
                        Icons.people_outline,
                        widget.onClients,
                      ),
                      _quickAction(
                        'المنتجات',
                        Icons.inventory_2_outlined,
                        widget.onProducts,
                      ),
                      _quickAction(
                        'دفتر اليومية',
                        Icons.menu_book_outlined,
                        widget.onJournal,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ملخص الحسابات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'تحديث الأرصدة',
                onPressed: state.loading ? null : widget.cubit.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (state.loading)
            const LinearProgressIndicator()
          else if (state.error != null) ...[
            ErrorNotice(state.error!),
            TextButton(
              onPressed: widget.cubit.refresh,
              child: const Text('إعادة المحاولة'),
            ),
          ] else if (state.summary != null)
            LayoutBuilder(
              builder: (context, size) => Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final item in [
                    (
                      'ديون العملاء',
                      'receivables_minor',
                      'المبالغ التي يدين بها العملاء',
                    ),
                    (
                      'المبالغ التي تدين بها',
                      'payables_minor',
                      'المبالغ التي تدين بها للعملاء',
                    ),
                    (
                      'صافي المستحقات',
                      'net_minor',
                      'الديون مطروحاً منها ما تدين به',
                    ),
                  ])
                    Container(
                      width: size.maxWidth >= 800
                          ? (size.maxWidth - 32) / 3
                          : size.maxWidth,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: line),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$1,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 26),
                          Text(
                            egp(state.summary![item.$2] as int),
                            style: const TextStyle(
                              fontSize: 24,
                              color: teal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            item.$3,
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'بناءً على الأرصدة الافتتاحية والفواتير والمدفوعات والدفعات المسجلة.',
            style: TextStyle(color: muted),
          ),
          if (state.summary?['clients'] is List) ...[
            const SizedBox(height: 28),
            const Text(
              'تفصيل الأرصدة حسب العميل',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (final raw in (state.summary!['clients'] as List)
                      .whereType<Map>()
                      .where((client) => ((client['balance_minor'] as num?) ?? 0) != 0)
                      .take(10))
                    ListTile(
                      dense: true,
                      title: Text('${raw['name'] ?? ''}'),
                      subtitle: Text(
                        (raw['balance_minor'] as num? ?? 0) >= 0
                            ? 'مدين لك'
                            : 'أنت مدين له',
                        style: const TextStyle(color: muted),
                      ),
                      trailing: Text(
                        egp(((raw['balance_minor'] as num?) ?? 0).abs().toInt()),
                        style: TextStyle(
                          color: (raw['balance_minor'] as num? ?? 0) >= 0
                              ? teal
                              : Colors.red.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          // ── Overdue clients section ──────────────────────────────
          Row(
            children: [
              const Expanded(
                child: Text(
                  'العملاء المتأخرون',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              if (state.overdueLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Day filter chips
          Wrap(
            spacing: 8,
            children: [
              for (final days in [7, 14, 30])
                ChoiceChip(
                  label: Text('$days أيام'),
                  selected: state.overdueDays == days,
                  onSelected: (_) => widget.cubit.setOverdueDays(days),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.overdueError != null)
            ErrorNotice(state.overdueError!)
          else if (!state.overdueLoading && state.overdueClients.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'لا يوجد عملاء متأخرون منذ ${state.overdueDays} يوم',
                style: const TextStyle(color: muted),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            Text(
              'عندك ${state.overdueClients.length} زبون ملهمش دفع من ${state.overdueDays} يوم',
              style: const TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < state.overdueClients.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _OverdueClientTile(
                      client: state.overdueClients[i],
                      api: widget.api,
                      tenantId: widget.tenantId,
                      onExpired: widget.onExpired,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _OverdueClientTile extends StatelessWidget {
  const _OverdueClientTile({
    required this.client,
    required this.api,
    required this.tenantId,
    required this.onExpired,
  });
  final Map<String, dynamic> client;
  final MuskyApi api;
  final int tenantId;
  final VoidCallback onExpired;

  @override
  Widget build(BuildContext context) {
    final balance = (client['balance_minor'] as num?)?.toInt() ?? 0;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClientDetailScreen(
            api: api,
            tenantId: tenantId,
            clientId: client['id'] as int,
            clientName: client['name'] as String? ?? '',
            onExpired: onExpired,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                client['name'] as String? ?? '',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              egp(balance),
              style: TextStyle(
                color: balance > 0 ? teal : muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: muted),
          ],
        ),
      ),
    );
  }
}
