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
  });
  final OverviewCubit cubit;
  final MuskyApi api;
  final int tenantId;
  final String name;
  final VoidCallback onExpired, onInvoices;
  @override
  State<FinancialOverview> createState() => _FinancialOverviewState();
}

class _FinancialOverviewState extends State<FinancialOverview> {
  @override
  void initState() {
    super.initState();
    widget.cubit.loadIfNeeded();
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<OverviewCubit, OverviewState>(
        bloc: widget.cubit,
        listener: (context, state) {
          if (state.expired) widget.onExpired();
        },
        builder: (context, state) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'نظرة سريعة على عملك',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'تحديث الأرصدة',
                    onPressed: state.loading ? null : widget.cubit.refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'مرحباً، ${widget.name}. إليك مساحة عملك.',
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 28),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
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
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              const Text(
                'بناءً على الفواتير المُصدرة والملغاة. المدفوعات والأرصدة الافتتاحية غير مدرجة بعد.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 36),
              // ── Overdue clients section ──────────────────────────────
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'العملاء المتأخرون',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
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
              const SizedBox(height: 36),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: ink,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'من المخزون إلى البيع',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'أنشئ مسودة، راجع الحزم والأسعار، ثم أصدر فاتورتك.',
                      style: TextStyle(color: Color(0xFFB6C9C1)),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: widget.onInvoices,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('فتح الفواتير'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDAEDCE),
                        foregroundColor: ink,
                      ),
                    ),
                  ],
                ),
              ),
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
