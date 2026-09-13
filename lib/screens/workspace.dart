import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../core/api.dart';
import '../core/theme.dart';
import 'records.dart';
import 'commerce.dart';
import 'financial_overview.dart';

class Workspace extends StatefulWidget {
  const Workspace({
    super.key,
    required this.api,
    required this.user,
    required this.onSignedOut,
  });
  final MuskyApi api;
  final AppUser user;
  final void Function([String? notice]) onSignedOut;
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  late String _section = widget.user.isSuperAdmin ? 'الأعمال' : 'نظرة عامة';
  late int? _tenantId = widget.user.tenantId;
  String? _tenantName;
  String? _logoUrl;
  bool _signingOut = false;
  @override
  void initState() {
    super.initState();
    _logoUrl = widget.user.logoUrl;
    _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    if (widget.user.tenantId == null) return;
    try {
      final user = await widget.api.currentUser();
      if (mounted) setState(() => _logoUrl = user.logoUrl);
    } catch (_) {
      // The login payload remains a valid fallback if profile refresh fails.
    }
  }

  void _expired() =>
      widget.onSignedOut('انتهت جلستك. يرجى تسجيل الدخول مجدداً.');
  Future<void> _logout() async {
    if (_signingOut) {
      return;
    }
    setState(() => _signingOut = true);
    String? notice;
    try {
      await widget.api.logout();
    } catch (_) {
      notice = 'تم تسجيل الخروج. تعذّر إنهاء الجلسة على الخادم.';
    }
    if (mounted) {
      widget.onSignedOut(notice);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, size) {
        final compact = size.maxWidth < 1000;
        final user = widget.user;
        Widget nav(String label, IconData icon, {bool enabled = true}) =>
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              child: Tooltip(
                message: label,
                child: Material(
                  color: _section == label
                      ? const Color(0xFFE7EFE5)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: enabled
                        ? () => setState(() => _section = label)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisAlignment: compact
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.start,
                        children: [
                          Icon(
                            icon,
                            size: 21,
                            color: !enabled
                                ? line
                                : _section == label
                                ? teal
                                : muted,
                          ),
                          if (!compact) ...[
                            const SizedBox(width: 13),
                            Expanded(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: _section == label
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: !enabled
                                      ? muted.withValues(alpha: .4)
                                      : _section == label
                                      ? teal
                                      : ink,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
        return Row(
          children: [
            Container(
              width: compact ? 80 : 224,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: line)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 30,
                      horizontal: 20,
                    ),
                    child: compact
                        ? const Icon(
                            Icons.inventory_2_outlined,
                            color: teal,
                            size: 30,
                          )
                        : const Brand(),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (!compact)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                12,
                                24,
                                12,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  user.isSuperAdmin ? 'المنصة' : 'مساحة العمل',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 1.5,
                                    color: muted,
                                  ),
                                ),
                              ),
                            ),
                          if (user.isSuperAdmin)
                            nav('الأعمال', Icons.domain_outlined),
                          nav(
                            'نظرة عامة',
                            Icons.space_dashboard_outlined,
                            enabled: _tenantId != null,
                          ),
                          nav(
                            'العملاء',
                            Icons.people_outline,
                            enabled: _tenantId != null,
                          ),
                          nav(
                            'المنتجات',
                            Icons.inventory_2_outlined,
                            enabled: _tenantId != null,
                          ),
                          nav(
                            'الفواتير',
                            Icons.receipt_long_outlined,
                            enabled: _tenantId != null,
                          ),
                          nav(
                            'الفريق',
                            Icons.badge_outlined,
                            enabled: _tenantId != null,
                          ),
                          nav('الحساب', Icons.person_outline),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Tooltip(
                      message: 'تسجيل الخروج',
                      child: TextButton(
                        onPressed: _signingOut ? null : _logout,
                        child: compact
                            ? const Icon(Icons.logout, size: 20)
                            : Row(
                                children: [
                                  const Icon(Icons.logout, size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    _signingOut
                                        ? 'جارٍ الخروج…'
                                        : 'تسجيل الخروج',
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 84,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 24 : 36,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: line)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _tenantName ??
                                    (_tenantId == null
                                        ? 'إدارة المنصة'
                                        : 'مساحة العمل التجارية'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _tenantId == null
                                    ? 'إدارة مساحات عمل التجار'
                                    : 'مساحة العمل #$_tenantId',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: paper,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            user.roleLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: teal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        CircleAvatar(
                          radius: 19,
                          backgroundColor: const Color(0xFFE7EFE5),
                          child: Text(
                            user.name.isEmpty
                                ? 'M'
                                : user.name.characters.first.toUpperCase(),
                            style: const TextStyle(color: teal),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(compact ? 24 : 36),
                      child: switch (_section) {
                        'المنتجات' || 'الفواتير' => CommerceScreen(
                          key: ValueKey('$_section:$_tenantId'),
                          api: widget.api,
                          tenantId: _tenantId!,
                          products: _section == 'المنتجات',
                          onExpired: _expired,
                        ),
                        'العملاء' || 'الفريق' || 'الأعمال' => RecordsScreen(
                          key: ValueKey('$_section:$_tenantId'),
                          api: widget.api,
                          user: user,
                          section: _section,
                          tenantId: _tenantId,
                          onExpired: _expired,
                          onTenant: (tenant) => setState(() {
                            _tenantId = tenant['id'] as int;
                            _tenantName = tenant['name'] as String;
                            _section = 'نظرة عامة';
                          }),
                        ),
                        'الحساب' => _account(),
                        _ => _overview(),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _overview() => FinancialOverview(
    key: ValueKey('overview:$_tenantId'),
    api: widget.api,
    tenantId: _tenantId!,
    name: widget.user.name,
    onExpired: _expired,
    onInvoices: () => setState(() => _section = 'الفواتير'),
  );
  Widget _account() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('حسابك', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'ملفك الشخصي وإعدادات تسجيل الدخول.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 28),
        Container(
          width: 620,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_logoUrl != null && _logoUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _logoUrl!,
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined, size: 48),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              for (final detail in [
                ('الاسم', widget.user.name),
                ('البريد الإلكتروني', widget.user.email),
                ('الدور', widget.user.roleLabel),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.$1,
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                      const SizedBox(height: 5),
                      SelectableText(detail.$2),
                    ],
                  ),
                ),
              const Divider(),
              if (_tenantId != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('تحديث شعار الشركة'),
                  onPressed: () async {
                    final file = await openFile(
                      acceptedTypeGroups: [
                        XTypeGroup(
                          label: 'Logo',
                          extensions: ['png', 'jpg', 'jpeg', 'webp'],
                        ),
                      ],
                    );
                    if (file == null || !mounted) {
                      return;
                    }
                    try {
                      final uploaded = await widget.api.uploadTenantLogo(
                        _tenantId!,
                        file.path,
                      );
                      if (mounted) {
                        setState(() => _logoUrl = uploaded['url'] as String?);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم تحديث شعار الشركة.'),
                          ),
                        );
                      }
                    } on ApiException catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('تغيير كلمة المرور'),
                onPressed: () async {
                  final changed = await showDialog<bool>(
                    context: context,
                    builder: (_) =>
                        PasswordDialog(api: widget.api, onExpired: _expired),
                  );
                  if (changed == true && mounted) {
                    widget.onSignedOut(
                      'تم تغيير كلمة المرور. سجّل دخولك بكلمتك الجديدة.',
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class PasswordDialog extends StatefulWidget {
  const PasswordDialog({super.key, required this.api, required this.onExpired});
  final MuskyApi api;
  final VoidCallback onExpired;
  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController(),
      _next = TextEditingController(),
      _confirm = TextEditingController();
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.changePassword(_current.text, _next.text);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.status == 401) {
        Navigator.pop(context);
        widget.onExpired();
      } else {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to change your password. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('تغيير كلمة المرور'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('سيتم تسجيل خروجك بعد تغيير كلمة المرور.'),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  ErrorNotice(_error!),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _current,
                  obscureText: true,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الحالية',
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? 'أدخل كلمة مرورك الحالية.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _next,
                  obscureText: true,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
                  ),
                  validator: (v) =>
                      utf8.encode(v ?? '').length < 12 ||
                          utf8.encode(v ?? '').length > 72
                      ? 'استخدم كلمة مرور من 12 إلى 72 حرفاً.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirm,
                  obscureText: true,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'تأكيد كلمة المرور الجديدة',
                  ),
                  validator: (v) =>
                      v != _next.text ? 'كلمتا المرور غير متطابقتين.' : null,
                  onFieldSubmitted: (_) => _save(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'جارٍ الحفظ…' : 'حفظ كلمة المرور'),
        ),
      ],
    ),
  );
}
