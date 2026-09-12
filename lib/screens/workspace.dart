import 'dart:convert';
import 'package:flutter/material.dart';
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
  late String _section = widget.user.isSuperAdmin ? 'Businesses' : 'Overview';
  late int? _tenantId = widget.user.tenantId;
  String? _tenantName;
  bool _signingOut = false;
  void _expired() =>
      widget.onSignedOut('Your session has expired. Please sign in again.');
  Future<void> _logout() async {
    if (_signingOut) {
      return;
    }
    setState(() => _signingOut = true);
    String? notice;
    try {
      await widget.api.logout();
    } catch (_) {
      notice =
          'Signed out on this device. The server could not be reached to end the remote session.';
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
                                  user.isSuperAdmin ? 'PLATFORM' : 'WORKSPACE',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 1.5,
                                    color: muted,
                                  ),
                                ),
                              ),
                            ),
                          if (user.isSuperAdmin)
                            nav('Businesses', Icons.domain_outlined),
                          nav(
                            'Overview',
                            Icons.space_dashboard_outlined,
                            enabled: _tenantId != null,
                          ),
                          nav(
                            'Clients',
                            Icons.people_outline,
                            enabled: _tenantId != null,
                          ),
                          nav(
                            'Products',
                            Icons.inventory_2_outlined,
                            enabled: _tenantId != null,
                          ),
                          nav(
                            'Invoices',
                            Icons.receipt_long_outlined,
                            enabled: _tenantId != null,
                          ),
                          nav(
                            'Team',
                            Icons.badge_outlined,
                            enabled: _tenantId != null,
                          ),
                          nav('Account', Icons.person_outline),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Tooltip(
                      message: 'Sign out',
                      child: TextButton(
                        onPressed: _signingOut ? null : _logout,
                        child: compact
                            ? const Icon(Icons.logout, size: 20)
                            : Row(
                                children: [
                                  const Icon(Icons.logout, size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    _signingOut ? 'Signing out…' : 'Sign out',
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
                                        ? 'Platform administration'
                                        : 'Your trading workspace'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _tenantId == null
                                    ? 'Manage trader workspaces'
                                    : 'Workspace #$_tenantId',
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
                        'Products' || 'Invoices' => CommerceScreen(
                          key: ValueKey('$_section:$_tenantId'),
                          api: widget.api,
                          tenantId: _tenantId!,
                          products: _section == 'Products',
                          onExpired: _expired,
                        ),
                        'Clients' || 'Team' || 'Businesses' => RecordsScreen(
                          key: ValueKey('$_section:$_tenantId'),
                          api: widget.api,
                          user: user,
                          section: _section,
                          tenantId: _tenantId,
                          onExpired: _expired,
                          onTenant: (tenant) => setState(() {
                            _tenantId = tenant['id'] as int;
                            _tenantName = tenant['name'] as String;
                            _section = 'Overview';
                          }),
                        ),
                        'Account' => _account(),
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
    onInvoices: () => setState(() => _section = 'Invoices'),
  );
  Widget _account() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your account', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Your profile and sign-in settings.',
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
              for (final detail in [
                ('Name', widget.user.name),
                ('Email', widget.user.email),
                ('Role', widget.user.roleLabel),
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
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Change password'),
                onPressed: () async {
                  final changed = await showDialog<bool>(
                    context: context,
                    builder: (_) =>
                        PasswordDialog(api: widget.api, onExpired: _expired),
                  );
                  if (changed == true && mounted) {
                    widget.onSignedOut(
                      'Password changed. Sign in with your new password.',
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
      title: const Text('Change password'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'You will be signed out after changing your password.',
                ),
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
                    labelText: 'Current password',
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Enter your current password.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _next,
                  obscureText: true,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'New password'),
                  validator: (v) =>
                      utf8.encode(v ?? '').length < 12 ||
                          utf8.encode(v ?? '').length > 72
                      ? 'Use a password of 12–72 bytes.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirm,
                  obscureText: true,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                  ),
                  validator: (v) =>
                      v != _next.text ? 'Passwords do not match.' : null,
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : 'Save password'),
        ),
      ],
    ),
  );
}
