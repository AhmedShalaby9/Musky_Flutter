import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musky/core/api.dart';
import 'package:musky/main.dart';

class FakeApi implements MuskyApi {
  final commerceSaved = <Map<String, dynamic>>[];
  final products = <Map<String, dynamic>>[
    {
      'id': 11,
      'title': 'Tea pack',
      'code': 'TEA',
      'quantity': 20,
      'pieces_per_unit': 12,
      'unit_price_minor': 2950,
      'version': 1,
      'active': true,
    },
  ];
  final invoices = <int, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    paths.add(path);
    final uri = Uri.parse(path);
    final clean = uri.path;
    if (clean.endsWith('/financial-summary')) {
      final total = invoices.values
          .where((v) => v['status'] == 'posted')
          .fold<int>(0, (sum, v) => sum + (v['total_minor'] as int));
      return {
        'currency': 'EGP',
        'receivables_minor': total,
        'payables_minor': 0,
        'net_minor': total,
        'scope': 'posted_invoices_and_voids',
      };
    }
    if (method != 'GET') {
      commerceSaved.add({'method': method, 'path': path, ...?body});
    }
    if (clean.endsWith('/clients')) {
      return {'data': clients};
    }
    if (clean.contains('/products')) {
      if (method == 'GET') {
        return {'data': products};
      }
      if (method == 'POST') {
        final created = {
          'id': products.length + 12,
          'active': true,
          ...body!,
          'version': 1,
        };
        products.add(created);
        return created;
      }
      final index = products.indexWhere(
        (p) => '${p['id']}' == clean.split('/').last,
      );
      products[index] = {
        ...products[index],
        ...body!,
        'version': (products[index]['version'] as int) + 1,
      };
      return products[index];
    }
    if (clean.endsWith('/invoices') && method == 'GET') {
      return {'data': invoices.values.toList()};
    }
    final parts = clean.split('/');
    final id = clean.endsWith('/invoices')
        ? invoices.length + 1
        : int.parse(parts[3]);
    if (method == 'GET') {
      return invoices[id]!;
    }
    if (method == 'POST' && clean.endsWith('/post')) {
      return invoices[id] = {
        ...invoices[id]!,
        'status': 'posted',
        'number': id,
        'version': (invoices[id]!['version'] as int) + 1,
      };
    }
    if (method == 'POST' && clean.endsWith('/void')) {
      return invoices[id] = {
        ...invoices[id]!,
        'status': 'void',
        'void_reason': body!['reason'],
        'version': (invoices[id]!['version'] as int) + 1,
      };
    }
    if (method == 'DELETE') {
      return invoices[id] = {
        ...invoices[id]!,
        'status': 'cancelled',
        'version': (invoices[id]!['version'] as int) + 1,
      };
    }
    final items = [
      for (final item in body!['items'] as List)
        {
          ...products.firstWhere((p) => p['id'] == item['product_id']),
          ...item as Map<String, dynamic>,
          'total_minor':
              (item['quantity'] as int) * (item['unit_price_minor'] as int),
        },
    ];
    return invoices[id] = {
      'id': id,
      'status': 'draft',
      'number': null,
      'currency': 'EGP',
      'client_name': 'Nile Trading',
      'client_address': 'Cairo',
      'void_reason': '',
      ...body,
      'items': items,
      'total_minor': items.fold<int>(
        0,
        (sum, item) => sum + (item['total_minor'] as int),
      ),
      'version': (invoices[id]?['version'] as int? ?? 0) + 1,
    };
  }

  AppUser user = const AppUser(
    id: 2,
    name: 'Ahmed',
    email: 'ahmed@example.com',
    role: 'trader',
    tenantId: 7,
  );
  ApiException? loginError, listError;
  final paths = <String>[];
  final saved = <Map<String, dynamic>>[];
  int logins = 0;
  bool cleared = false, loggedOut = false;
  List<Map<String, dynamic>> clients = [
    {
      'id': 1,
      'name': 'Nile Trading',
      'email': 'nile@example.com',
      'phone': '01000000000',
      'address': 'Cairo',
      'notes': '',
      'active': true,
    },
  ];
  @override
  String get address => 'http://127.0.0.1:8080/api/v1';
  @override
  Future<AppUser> login(String email, String password) async {
    logins++;
    if (loginError != null) {
      throw loginError!;
    }
    return user;
  }

  @override
  Future<AppUser> currentUser() async => user;

  @override
  Future<void> logout() async {
    loggedOut = true;
  }

  @override
  void clearSession() {
    cleared = true;
  }

  @override
  void dispose() {}
  @override
  Future<void> changePassword(String current, String next) async {}
  @override
  Future<Map<String, dynamic>> createTenant(
    String name,
    String traderName,
    String traderEmail,
    String traderPassword,
  ) async => {'id': 99, 'name': name, 'trader_id': 100};
  @override
  Future<Map<String, dynamic>> uploadTenantLogo(
    int tenantId,
    String path,
  ) async => {'url': 'https://example.test/logo.png'};
  @override
  Future<void> deleteTenantLogo(int tenantId) async {}
  @override
  Future<List<Map<String, dynamic>>> list(String path, {int offset = 0}) async {
    paths.add(path);
    if (listError != null) {
      throw listError!;
    }
    if (path == 'tenants') {
      return [
        {'id': 9, 'name': 'Trader Nine', 'active': true},
        {'id': 10, 'name': 'Trader Ten', 'active': true},
      ];
    }
    if (path.endsWith('/users')) {
      return [
        {
          'id': 2,
          'name': 'Ahmed',
          'email': 'ahmed@example.com',
          'role': 'trader',
          'active': true,
        },
      ];
    }
    return clients;
  }

  @override
  Future<void> saveClient(
    int tenantId,
    Map<String, dynamic> data, {
    int? id,
  }) async {
    saved.add({'tenant': tenantId, 'id': id, ...data});
  }
}

Future<void> start(
  WidgetTester tester,
  FakeApi api, {
  Size size = const Size(1280, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('preview'),
      child: MuskyApp(api: api),
    ),
  );
}

Future<void> signIn(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email address'),
    'ahmed@example.com',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    'test-password-123',
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('validates login and shows server errors', (tester) async {
    final api = FakeApi()
      ..loginError = const ApiException('invalid email or password', 401);
    await start(tester, api);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(api.logins, 0);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    await signIn(tester);
    expect(find.text('invalid email or password'), findsOneWidget);
    expect(find.text('Your business, at a glance'), findsNothing);
  });
  testWidgets('trader navigation scopes clients and saves changes', (
    tester,
  ) async {
    final api = FakeApi();
    await start(tester, api);
    await signIn(tester);
    expect(find.text('Businesses'), findsNothing);
    expect(find.text('EGP 0.00'), findsNWidgets(3));
    await tester.tap(find.text('Clients').first);
    await tester.pumpAndSettle();
    expect(api.paths.last, 'tenants/7/clients');
    expect(find.text('Nile Trading'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'missing');
    await tester.pumpAndSettle();
    expect(find.text('No matching records on this page'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add client'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Client name'),
      'New Client',
    );
    await tester.tap(find.text('Save client'));
    await tester.pumpAndSettle();
    expect(api.saved.single['tenant'], 7);
    expect(api.saved.single['name'], 'New Client');
    expect(api.saved.single.containsKey('user_id'), false);
    await tester.tap(find.byTooltip('Edit Nile Trading'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Client name'),
      'Updated Client',
    );
    await tester.tap(find.text('Save client'));
    await tester.pumpAndSettle();
    expect(api.saved.last['id'], 1);
    expect(api.saved.last['name'], 'Updated Client');
    await tester.tap(find.byTooltip('Archive Nile Trading'));
    await tester.pumpAndSettle();
    expect(api.saved.last['active'], false);
    expect(tester.takeException(), isNull);
  });
  testWidgets('expired session clears workspace and returns to login', (
    tester,
  ) async {
    final api = FakeApi()
      ..listError = const ApiException('session expired', 401);
    await start(tester, api);
    await signIn(tester);
    await tester.tap(find.text('Clients').first);
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(
      find.text('Your session has expired. Please sign in again.'),
      findsOneWidget,
    );
    expect(api.cleared, true);
  });
  testWidgets('super admin chooses a workspace before loading tenant records', (
    tester,
  ) async {
    final api = FakeApi()
      ..user = const AppUser(
        id: 1,
        name: 'Owner',
        email: 'owner@example.com',
        role: 'super_admin',
      );
    await start(tester, api);
    await signIn(tester);
    expect(api.paths, ['tenants']);
    await tester.tap(find.text('Open workspace').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clients').first);
    await tester.pumpAndSettle();
    expect(api.paths.last, 'tenants/9/clients');
    await tester.tap(find.text('Businesses').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open workspace').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clients').first);
    await tester.pumpAndSettle();
    expect(api.paths.last, 'tenants/10/clients');
  });
  testWidgets('logout revokes session and clears local state', (tester) async {
    final api = FakeApi();
    await start(tester, api);
    await signIn(tester);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(api.loggedOut, true);
    expect(api.cleared, true);
    expect(find.text('Welcome back'), findsOneWidget);
  });
  testWidgets('changing a password returns to login', (tester) async {
    final api = FakeApi();
    await start(tester, api);
    await signIn(tester);
    await tester.tap(find.text('Account').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Current password'),
      'old-password-123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      'new-password-123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm new password'),
      'new-password-123',
    );
    await tester.tap(find.text('Save password'));
    await tester.pumpAndSettle();
    expect(
      find.text('Password changed. Sign in with your new password.'),
      findsOneWidget,
    );
    expect(api.cleared, true);
  });
  testWidgets('compact desktop window has no layout overflow', (tester) async {
    final api = FakeApi();
    await start(tester, api, size: const Size(800, 600));
    await signIn(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Clients'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('desktop visual previews', (tester) async {
    final directory = Platform.environment['MUSKY_PREVIEW_DIR'];
    if (directory == null) {
      return;
    }
    await tester.runAsync(() async {
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final font = File('C:/Windows/Fonts/segoeui.ttf');
      if (await font.exists()) {
        final loader = FontLoader('Roboto')
          ..addFont(
            font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        await loader.load();
      }
    });
    final api = FakeApi();
    await start(tester, api);
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('preview')),
      );
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    }

    await tester.runAsync(() => capture('login'));
    await signIn(tester);
    await tester.runAsync(() => capture('workspace'));
    await tester.tap(find.text('Clients').first);
    await tester.pumpAndSettle();
    await tester.runAsync(() => capture('clients'));
    await tester.tap(find.text('Products').first);
    await tester.pumpAndSettle();
    await tester.runAsync(() => capture('products'));
    await tester.tap(find.text('Invoices').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New invoice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select client'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nile Trading'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add product line'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tea pack'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quantity (packs)'),
      '3',
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => capture('invoice-editor'));
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => capture('invoice-detail'));
  });
}
