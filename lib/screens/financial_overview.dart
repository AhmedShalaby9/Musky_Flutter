import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/money.dart';
import '../core/theme.dart';

class FinancialOverview extends StatefulWidget {
  const FinancialOverview({
    super.key,
    required this.api,
    required this.tenantId,
    required this.name,
    required this.onExpired,
    required this.onInvoices,
  });
  final MuskyApi api;
  final int tenantId;
  final String name;
  final VoidCallback onExpired, onInvoices;
  @override
  State<FinancialOverview> createState() => _FinancialOverviewState();
}

class _FinancialOverviewState extends State<FinancialOverview> {
  Map<String, dynamic>? _summary;
  String? _error;
  bool _busy = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final summary = await widget.api.request(
        'GET',
        'tenants/${widget.tenantId}/financial-summary',
      );
      if (mounted) {
        setState(() => _summary = summary);
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (e.status == 401) {
          widget.onExpired();
        } else {
          setState(() => _error = e.message);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to load balances. Please retry.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Your business, at a glance',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            IconButton(
              tooltip: 'Refresh balances',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Welcome, ${widget.name}. Here is your workspace.',
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 28),
        if (_busy)
          const LinearProgressIndicator()
        else if (_error != null) ...[
          ErrorNotice(_error!),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ] else
          LayoutBuilder(
            builder: (context, size) => Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final item in [
                  (
                    'Client debts',
                    'receivables_minor',
                    'Money clients owe you',
                  ),
                  (
                    'Amounts you owe',
                    'payables_minor',
                    'Money you owe clients',
                  ),
                  (
                    'Net outstanding',
                    'net_minor',
                    'Debts minus amounts you owe',
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
                          egp(_summary![item.$2] as int),
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
          'Based on posted sales invoices and voids. Payments and opening balances are not included yet.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 30),
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
                'From stock to sale',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Create a draft, review the packs and prices, then post your invoice.',
                style: TextStyle(color: Color(0xFFB6C9C1)),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: widget.onInvoices,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Open invoices'),
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
  );
}
