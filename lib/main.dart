import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/api.dart';
import 'core/theme.dart';
import 'screens/login.dart';
import 'screens/workspace.dart';

void main() => runApp(const MuskyApp());

class MuskyApp extends StatefulWidget {
  const MuskyApp({super.key, this.api});
  final MuskyApi? api;
  @override
  State<MuskyApp> createState() => _MuskyAppState();
}

class _MuskyAppState extends State<MuskyApp> {
  MuskyApi? _api;
  AppUser? _user;
  String? _notice;
  String? _configurationError;
  @override
  void initState() {
    super.initState();
    try {
      _api = widget.api ?? HttpMuskyApi();
    } on ApiException catch (e) {
      _configurationError = e.message;
    }
  }

  void _signedOut([String? notice]) {
    _api?.clearSession();
    setState(() {
      _user = null;
      _notice = notice;
    });
  }

  @override
  void dispose() {
    _api?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Musky',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: muskyTheme(),
    home: _api == null
        ? Scaffold(
            body: Center(
              child: SizedBox(
                width: 480,
                child: ErrorNotice(
                  _configurationError ?? 'Unable to configure Musky.',
                ),
              ),
            ),
          )
        : _user == null
        ? LoginScreen(
            api: _api!,
            notice: _notice,
            onLogin: (user) {
              setState(() {
                _user = user;
                _notice = null;
              });
            },
          )
        : Workspace(api: _api!, user: _user!, onSignedOut: _signedOut),
  );
}
