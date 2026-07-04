import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  AppConfig({
    this.baseUrl = '',
    this.lastBaseUrl = '',
    this.deviceUuid = '',
    this.deviceName = '',
    this.pairingCode = '',
    this.deviceApproved = false,
    this.empresaId,
    this.empresaNome = '',
    this.token = '',
    this.userId,
    this.userName = '',
    this.vendedorId,
    this.lastSyncIso,
  });

  String baseUrl;
  String lastBaseUrl;
  String deviceUuid;
  String deviceName;
  String pairingCode;
  bool deviceApproved;
  int? empresaId;
  String empresaNome;
  String token;
  int? userId;
  String userName;
  int? vendedorId;
  String? lastSyncIso;

  bool get isConnected => baseUrl.isNotEmpty;
  bool get isApproved => deviceApproved;
  bool get isLoggedIn => token.isNotEmpty;

  String get apiBase => '$baseUrl/api/v1/vendas-internas';

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'lastBaseUrl': lastBaseUrl,
        'deviceUuid': deviceUuid,
        'deviceName': deviceName,
        'pairingCode': pairingCode,
        'deviceApproved': deviceApproved,
        'empresaId': empresaId,
        'empresaNome': empresaNome,
        'token': token,
        'userId': userId,
        'userName': userName,
        'vendedorId': vendedorId,
        'lastSyncIso': lastSyncIso,
      };

  static AppConfig fromJson(Map<String, dynamic> j) => AppConfig(
        baseUrl: j['baseUrl'] ?? '',
        lastBaseUrl: j['lastBaseUrl'] ?? '',
        deviceUuid: j['deviceUuid'] ?? '',
        deviceName: j['deviceName'] ?? '',
        pairingCode: j['pairingCode'] ?? '',
        deviceApproved: j['deviceApproved'] ?? false,
        empresaId: j['empresaId'],
        empresaNome: j['empresaNome'] ?? '',
        token: j['token'] ?? '',
        userId: j['userId'],
        userName: j['userName'] ?? '',
        vendedorId: j['vendedorId'],
        lastSyncIso: j['lastSyncIso'],
      );

  static const _key = 'unitec_vi_config';

  static Future<AppConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return AppConfig();
    try {
      return AppConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AppConfig();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }

  void clearSession() {
    token = '';
    userId = null;
    userName = '';
    vendedorId = null;
  }
}
