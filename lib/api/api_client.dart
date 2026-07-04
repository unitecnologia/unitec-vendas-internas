import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_info.dart';
import '../config.dart';
import '../log/app_log.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class PingResult {
  PingResult({required this.ok, required this.message, this.ms});

  final bool ok;
  final String message;
  final int? ms;
}

class ApiClient {
  ApiClient(this.config);

  final AppConfig config;
  final http.Client _http = http.Client();

  Duration timeout = const Duration(seconds: 20);

  Map<String, String> _headers({bool auth = false, Map<String, String>? extra}) {
    final h = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (config.deviceUuid.isNotEmpty) 'X-VI-Device': config.deviceUuid,
      if (auth && config.token.isNotEmpty) 'Authorization': 'Bearer ${config.token}',
    };
    if (extra != null) h.addAll(extra);
    return h;
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${config.apiBase}/$path').replace(queryParameters: query);

  static Future<bool> pingBase(String baseUrl, {Duration timeout = const Duration(seconds: 2)}) async {
    final r = await pingDetailed(baseUrl, timeout: timeout);
    return r.ok;
  }

  static Future<PingResult> pingDetailed(String baseUrl, {Duration timeout = const Duration(seconds: 5)}) async {
    final sw = Stopwatch()..start();
    try {
      final uri = Uri.parse('$baseUrl/api/v1/vendas-internas/ping');
      final r = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(timeout);
      sw.stop();
      if (r.statusCode != 200) {
        return PingResult(ok: false, message: 'HTTP ${r.statusCode}', ms: sw.elapsedMilliseconds);
      }
      final body = jsonDecode(r.body);
      final okBody = body is Map && (body['ok'] == true || body['server_time'] != null);
      return PingResult(ok: okBody, message: okBody ? 'OK' : 'Resposta inesperada', ms: sw.elapsedMilliseconds);
    } on TimeoutException {
      sw.stop();
      return PingResult(ok: false, message: 'Tempo esgotado', ms: sw.elapsedMilliseconds);
    } catch (e) {
      sw.stop();
      return PingResult(ok: false, message: e.toString(), ms: sw.elapsedMilliseconds);
    }
  }

  Future<Map<String, dynamic>> registerDevice({String? deviceName}) async {
    final r = await _http
        .post(
          _uri('devices/register'),
          headers: _headers(),
          body: jsonEncode({
            'device_uuid': config.deviceUuid,
            'device_name': deviceName ?? config.deviceName,
            'platform': 'android',
            'app_version': kAppVersion,
          }),
        )
        .timeout(timeout);
    return _decode(r);
  }

  Future<Map<String, dynamic>> deviceStatus() async {
    final r = await _http
        .get(_uri('devices/status', {'device_uuid': config.deviceUuid}), headers: _headers())
        .timeout(timeout);
    return _decode(r);
  }

  Future<Map<String, dynamic>> info() async {
    final r = await _http.get(_uri('info'), headers: _headers()).timeout(timeout);
    return _decode(r);
  }

  Future<List<dynamic>> usuarios(int empresaId) async {
    final r = await _http
        .get(_uri('users', {'empresa_id': '$empresaId'}), headers: _headers())
        .timeout(timeout);
    return (_decode(r)['users'] as List<dynamic>? ?? []);
  }

  Future<Map<String, dynamic>> login({
    required int empresaId,
    required int userId,
    required String senha,
  }) async {
    final r = await _http
        .post(
          _uri('auth/login'),
          headers: _headers(),
          body: jsonEncode({
            'empresa_id': empresaId,
            'user_id': userId,
            'senha': senha,
            'device_uuid': config.deviceUuid,
            'device_name': config.deviceName,
            'platform': 'android',
            'app_version': kAppVersion,
          }),
        )
        .timeout(timeout);
    return _decode(r);
  }

  Future<void> logout() async {
    try {
      await _http.post(_uri('auth/logout'), headers: _headers(auth: true)).timeout(timeout);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> pull({String? since, String? etag}) async {
    final r = await _http
        .get(
          _uri('sync/pull', since != null ? {'since': since} : null),
          headers: _headers(auth: true, extra: etag != null ? {'If-None-Match': etag} : null),
        )
        .timeout(const Duration(seconds: 40));
    if (r.statusCode == 304) return null;
    final data = _decode(r);
    data['_etag'] = r.headers['etag'];
    return data;
  }

  Future<Map<String, dynamic>> push(List<Map<String, dynamic>> orders) async {
    final r = await _http
        .post(
          _uri('sync/push'),
          headers: _headers(auth: true),
          body: jsonEncode({'orders': orders}),
        )
        .timeout(const Duration(seconds: 30));
    return _decode(r);
  }

  Map<String, dynamic> _decode(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (r.body.isEmpty) return {};
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    var msg = 'Erro ${r.statusCode}';
    try {
      final body = jsonDecode(r.body);
      if (body is Map && body['message'] != null) msg = body['message'].toString();
    } catch (_) {}
    AppLog.instance.error('api', msg);
    throw ApiException(msg, statusCode: r.statusCode);
  }
}
