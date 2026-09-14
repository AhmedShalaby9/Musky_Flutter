import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ApiException implements Exception {
  const ApiException(this.message, [this.status]);
  final String message;
  final int? status;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.tenantId,
    this.logoUrl,
  });
  final int id;
  final String name, email, role;
  final int? tenantId;
  final String? logoUrl;
  bool get isSuperAdmin => role == 'super_admin';
  String get roleLabel => switch (role) {
    'super_admin' => 'Super admin',
    'trader' => 'Trader',
    _ => 'Admin',
  };
  factory AppUser.fromJson(Map<String, dynamic> json) {
    final role = json['role'] as String;
    if (!['super_admin', 'admin', 'trader'].contains(role) ||
        (role != 'super_admin' && json['tenant_id'] is! int)) {
      throw const FormatException('Invalid account');
    }
    return AppUser(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: role,
      tenantId: json['tenant_id'] as int?,
      logoUrl: json['logo_url'] as String?,
    );
  }
}

abstract class MuskyApi {
  String get address;
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]);
  Future<AppUser> login(String email, String password);
  Future<AppUser> currentUser();
  Future<void> logout();
  Future<void> changePassword(String current, String next);
  Future<List<Map<String, dynamic>>> list(String path, {int offset = 0, String q = ''});
  Future<void> saveClient(int tenantId, Map<String, dynamic> data, {int? id});
  Future<Map<String, dynamic>> recordPayment(
    int tenantId,
    int invoiceId,
    int amountMinor,
    String method,
    String notes,
  );
  Future<Map<String, dynamic>> createTenant(
    String name,
    String traderName,
    String traderEmail,
    String traderPassword,
  );
  Future<Map<String, dynamic>> uploadTenantLogo(int tenantId, String path);
  Future<void> deleteTenantLogo(int tenantId);
  void clearSession();
  void dispose();
}

class HttpMuskyApi implements MuskyApi {
  HttpMuskyApi({
    String address = const String.fromEnvironment(
      'MUSKY_API_URL',
      defaultValue: 'http://169.58.36.30/api/v1',
    ),
  }) : _base = Uri.parse(address) {
    if (!_base.hasAuthority ||
        _base.userInfo.isNotEmpty ||
        _base.hasQuery ||
        _base.hasFragment ||
        (_base.scheme != 'https' && _base.scheme != 'http')) {
      throw const ApiException('Invalid server address.');
    }
  }
  final Uri _base;
  String? _token;
  HttpClient? _uploadClient;
  @override
  String get address => _base.toString();

  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) => _request(method, path, body);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      return await (() async {
        final request = await client.openUrl(
          method,
          Uri.parse('${address.replaceAll(RegExp(r'/+$'), '')}/$path'),
        );
        request.followRedirects = false;
        request.headers.contentType = ContentType.json;
        if (_token != null) {
          request.headers.set('Authorization', 'Bearer $_token');
        }
        if (body != null) {
          request.write(jsonEncode(body));
        }
        final response = await request.close();
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length > 2 * 1024 * 1024) {
            throw const ApiException('The server response is too large.');
          }
        }
        Map<String, dynamic> data = {};
        if (bytes.isNotEmpty) {
          final decoded = jsonDecode(utf8.decode(bytes));
          if (decoded is! Map<String, dynamic>) {
            throw const FormatException();
          }
          data = decoded;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw ApiException(
            response.statusCode >= 500
                ? 'The server is temporarily unavailable. Try again.'
                : (data['error'] as String? ??
                      'The request could not be completed.'),
            response.statusCode,
          );
        }
        return data;
      })().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const ApiException(
        'The connection timed out. Check your server and try again.',
      );
    } on SocketException {
      throw const ApiException(
        'Cannot connect to Musky. Check that your server is running.',
      );
    } on HandshakeException {
      throw const ApiException(
        'The server security certificate could not be verified.',
      );
    } on HttpException {
      throw const ApiException(
        'The connection was interrupted. Please try again.',
      );
    } on FormatException {
      throw const ApiException(
        'Unexpected server response. Check the API address.',
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<AppUser> login(String email, String password) async {
    _token = null;
    final data = await _request('POST', 'auth/login', {
      'email': email.trim(),
      'password': password,
    });
    try {
      final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
      final token = data['access_token'] as String;
      if (token.isEmpty) {
        throw const FormatException();
      }
      _token = token;
      return user;
    } catch (_) {
      throw const ApiException(
        'Unexpected login response. Check the API address.',
      );
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _request('POST', 'auth/logout');
    } finally {
      clearSession();
    }
  }

  @override
  Future<AppUser> currentUser() async {
    final data = await _request('GET', 'me');
    try {
      return AppUser.fromJson(data);
    } catch (_) {
      throw const ApiException('Unexpected account response.');
    }
  }

  @override
  Future<void> changePassword(String current, String next) async {
    await _request('PUT', 'me/password', {
      'current_password': current,
      'new_password': next,
    });
    clearSession();
  }

  @override
  Future<List<Map<String, dynamic>>> list(String path, {int offset = 0, String q = ''}) async {
    var url = '$path?limit=50&offset=$offset';
    if (q.isNotEmpty) url += '&q=${Uri.encodeQueryComponent(q)}';
    final data = await _request('GET', url);
    try {
      return (data['data'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      throw const ApiException('Unexpected list response. Please try again.');
    }
  }

  @override
  Future<void> saveClient(
    int tenantId,
    Map<String, dynamic> data, {
    int? id,
  }) async {
    await _request(
      id == null ? 'POST' : 'PATCH',
      'tenants/$tenantId/clients${id == null ? '' : '/$id'}',
      data,
    );
  }

  @override
  Future<Map<String, dynamic>> recordPayment(
    int tenantId,
    int invoiceId,
    int amountMinor,
    String method,
    String notes,
  ) => _request('POST', 'tenants/$tenantId/invoices/$invoiceId/payments', {
    'amount_minor': amountMinor,
    'method': method,
    'notes': notes,
  });

  @override
  Future<Map<String, dynamic>> createTenant(
    String name,
    String traderName,
    String traderEmail,
    String traderPassword,
  ) => _request('POST', 'tenants', {
    'name': name,
    'trader': {
      'name': traderName,
      'email': traderEmail,
      'password': traderPassword,
      'role': 'trader',
    },
  });

  @override
  Future<Map<String, dynamic>> uploadTenantLogo(
    int tenantId,
    String path,
  ) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final name = path.split(RegExp(r'[\\/]')).last;
    final extension = name.toLowerCase().split('.').last;
    final contentType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => 'image/png',
    };
    final boundary = 'musky-${DateTime.now().microsecondsSinceEpoch}';
    final request = await _openMultipart(
      'POST',
      'tenants/$tenantId/logo',
      boundary,
    );
    request.headers.contentType = ContentType(
      'multipart',
      'form-data',
      parameters: {'boundary': boundary},
    );
    request.write(
      '--$boundary\r\nContent-Disposition: form-data; name="file"; filename="${name.replaceAll('"', '')}"\r\nContent-Type: $contentType\r\n\r\n',
    );
    request.add(bytes);
    request.write('\r\n--$boundary--\r\n');
    return _finish(request);
  }

  Future<HttpClientRequest> _openMultipart(
    String method,
    String path,
    String boundary,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    final request = await client.openUrl(
      method,
      Uri.parse('${address.replaceAll(RegExp(r'/+$'), '')}/$path'),
    );
    request.followRedirects = false;
    if (_token != null) request.headers.set('Authorization', 'Bearer $_token');
    request.headers.set(
      'Content-Type',
      'multipart/form-data; boundary=$boundary',
    );
    _uploadClient = client;
    return request;
  }

  Future<Map<String, dynamic>> _finish(HttpClientRequest request) async {
    final response = await request.close().timeout(const Duration(seconds: 30));
    final text = await response.transform(utf8.decoder).join();
    _uploadClient?.close(force: true);
    _uploadClient = null;
    final data = text.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(text) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        data['error'] as String? ?? 'The upload could not be completed.',
        response.statusCode,
      );
    }
    return data;
  }

  @override
  Future<void> deleteTenantLogo(int tenantId) async {
    await _request('DELETE', 'tenants/$tenantId/logo');
  }

  @override
  void clearSession() {
    _token = null;
  }

  @override
  void dispose() => clearSession();
}
