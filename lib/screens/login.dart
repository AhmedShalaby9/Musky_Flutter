import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.api,
    required this.onLogin,
    this.notice,
  });
  final MuskyApi api;
  final ValueChanged<AppUser> onLogin;
  final String? notice;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false, _obscure = true;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await widget.api.login(_email.text, _password.text);
      if (mounted) {
        _password.clear();
        widget.onLogin(user);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.status != null ? '${e.message} [${e.status}]' : e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to sign in. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, size) {
        final wide = size.maxWidth >= 900 && size.maxHeight >= 640;
        final form = Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(wide ? 56 : 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!wide) ...[const Brand(), const SizedBox(height: 48)],
                    Text(
                      'مرحباً بعودتك',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'سجّل دخولك إلى مساحة العمل.',
                      style: TextStyle(color: muted, fontSize: 15),
                    ),
                    const SizedBox(height: 32),
                    if (widget.notice != null) ...[
                      Text(widget.notice!, style: const TextStyle(color: teal)),
                      const SizedBox(height: 20),
                    ],
                    if (_error != null) ...[
                      ErrorNotice(_error!),
                      const SizedBox(height: 20),
                    ],
                    TextFormField(
                      controller: _email,
                      enabled: !_busy,
                      autofocus: true,
                      autofillHints: const [AutofillHints.username],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        hintText: 'you@example.com',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (value) =>
                          value == null ||
                              !RegExp(
                                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                              ).hasMatch(value.trim())
                          ? 'أدخل بريداً إلكترونياً صحيحاً.'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: _obscure,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscure
                              ? 'إظهار كلمة المرور'
                              : 'إخفاء كلمة المرور',
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'أدخل كلمة المرور.'
                          : null,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('تسجيل الدخول'),
                                  SizedBox(width: 12),
                                  Icon(Icons.arrow_forward, size: 18),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'تحتاج إلى حساب أو إعادة تعيين كلمة المرور؟\nتواصل مع مسؤول النظام.',
                      style: TextStyle(color: muted, height: 1.6),
                    ),
                    const SizedBox(height: 48),
                    Row(
                      children: [
                        const Icon(Icons.dns_outlined, size: 15, color: muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.api.address,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        return Row(
          children: [
            if (wide)
              Expanded(
                child: Container(
                  color: ink,
                  padding: const EdgeInsets.all(56),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Brand(light: true),
                      const Spacer(),
                      const Text(
                        'رؤية أوضح\nلعملك.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 44,
                          height: 1.16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'عملاؤك. مخزونك. مساحة عملك.\nكل شيء في مكان واحد.',
                        style: TextStyle(
                          color: Color(0xFFB6C9C1),
                          fontSize: 16,
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .1),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.lock_person_outlined,
                              color: Color(0xFFB7D9A5),
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'مساحة عمل مخصصة لكل تاجر.',
                                style: TextStyle(
                                  color: Colors.white,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'MUSKY  /  مساحة العمل',
                        style: TextStyle(
                          color: Color(0xFFB6C9C1),
                          fontSize: 11,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(child: form),
          ],
        );
      },
    ),
  );
}
