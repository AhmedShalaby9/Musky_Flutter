import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:musky/core/api.dart';

void main() {
  test('rejects credentials and unsupported API URL schemes', () {
    for (final url in [
      'https://user:password@example.com/api/v1',
      'ftp://localhost/api/v1',
    ]) {
      expect(() => HttpMuskyApi(address: url), throwsA(isA<ApiException>()));
    }
  });
  test('uses API routes, bearer token, and explicit tenant paths', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requests = <String>[], authorization = <String?>[];
    server.listen((request) async {
      requests.add(request.uri.toString());
      authorization.add(request.headers.value('Authorization'));
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.endsWith('/auth/login')) {
        final data = jsonDecode(await utf8.decoder.bind(request).join());
        expect(data['email'], 'user@example.com');
        request.response.write(
          jsonEncode({
            'access_token': 'test-token',
            'user': {
              'id': 2,
              'tenant_id': 7,
              'name': 'User',
              'email': 'user@example.com',
              'role': 'trader',
            },
          }),
        );
      } else if (request.uri.path.endsWith('/auth/logout')) {
        request.response.statusCode = 204;
      } else {
        request.response.write('{"data":[]}');
      }
      await request.response.close();
    });
    final api = HttpMuskyApi(
      address: 'http://127.0.0.1:${server.port}/api/v1/',
    );
    addTearDown(api.dispose);
    final user = await api.login(' user@example.com ', 'password');
    expect(user.tenantId, 7);
    await api.list('tenants/7/clients', offset: 50);
    await api.logout();
    await api.list('tenants/7/clients');
    expect(requests[1], '/api/v1/tenants/7/clients?limit=50&offset=50');
    expect(authorization, [
      null,
      'Bearer test-token',
      'Bearer test-token',
      null,
    ]);
  });
  test('preserves server status for session expiry', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.statusCode = 401;
      request.response.write('{"error":"session expired"}');
      await request.response.close();
    });
    final api = HttpMuskyApi(address: 'http://127.0.0.1:${server.port}/api/v1');
    addTearDown(api.dispose);
    await expectLater(
      api.list('tenants/7/clients'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );
  });
}
