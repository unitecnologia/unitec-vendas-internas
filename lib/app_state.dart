import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'api/api_client.dart';
import 'config.dart';
import 'log/app_log.dart';
import 'net/server_ports.dart';
import 'sync/sync_service.dart';

class AppState extends ChangeNotifier {
  AppState(this.config) : api = ApiClient(config) {
    sync = SyncService(config, api);
  }

  Future<void> initialize() async {
    if (config.isLoggedIn) sync.start();
  }

  final AppConfig config;
  final ApiClient api;
  late final SyncService sync;

  bool get isConnected => config.isConnected;
  bool get isApproved => config.isApproved;
  bool get isLoggedIn => config.isLoggedIn;

  Future<void> ensureDeviceIdentity() async {
    var changed = false;
    if (config.deviceUuid.isEmpty) {
      config.deviceUuid = const Uuid().v4();
      changed = true;
    }
    if (config.deviceName.isEmpty) {
      config.deviceName = await _defaultDeviceName();
      changed = true;
    }
    if (changed) {
      await config.save();
      notifyListeners();
    }
  }

  Future<String> _defaultDeviceName() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return '${info.brand} ${info.model}'.trim();
    } catch (_) {
      return 'Aparelho Android';
    }
  }

  Future<void> connectManual(String url) async {
    final candidates = ServerPorts.connectionCandidates(url);
    if (candidates.isEmpty) {
      throw Exception('Informe o endereço do servidor.');
    }

    Object? lastError;
    for (final candidate in candidates) {
      try {
        await _pingAndConnect(candidate);
        return;
      } catch (e) {
        lastError = e;
      }
    }

    final dev = ServerPorts.devPort;
    final prod = ServerPorts.productionPort;
    throw Exception(
      'Não foi possível conectar.\n'
      'Dev: IP:$dev · Produção: IP:$prod (mesma rede Wi‑Fi do PC).\n'
      '${lastError ?? ''}',
    );
  }

  Future<void> _pingAndConnect(String baseUrl) async {
    AppLog.instance.info('conexão', 'Testando $baseUrl');
    final r = await ApiClient.pingDetailed(baseUrl, timeout: const Duration(seconds: 5));
    if (!r.ok) {
      AppLog.instance.error('conexão', 'Falhou em $baseUrl: ${r.message}');
      throw Exception('Não respondeu em $baseUrl (${r.message})');
    }
    AppLog.instance.ok('conexão', 'Conectado a $baseUrl (${r.ms} ms)');
    await _applyConnection(baseUrl);
  }

  Future<void> connectFound(String baseUrl) async {
    AppLog.instance.ok('conexão', 'Servidor encontrado: $baseUrl');
    await _applyConnection(baseUrl);
  }

  Future<void> _applyConnection(String baseUrl) async {
    config.baseUrl = baseUrl;
    config.lastBaseUrl = baseUrl;
    await ensureDeviceIdentity();
    config.deviceApproved = false;
    await config.save();
    notifyListeners();
  }

  Future<String> registerDevice() async {
    await ensureDeviceIdentity();
    final resp = await api.registerDevice(deviceName: config.deviceName);
    config.pairingCode = (resp['pairing_code'] ?? '').toString();
    config.deviceApproved = resp['approved'] == true;
    await config.save();
    notifyListeners();
    return config.pairingCode;
  }

  Future<String> refreshApproval() async {
    final resp = await api.deviceStatus();
    final status = (resp['status'] ?? 'desconhecido').toString();
    final approved = resp['approved'] == true;
    if (resp['pairing_code'] != null) config.pairingCode = resp['pairing_code'].toString();
    if (approved != config.deviceApproved) {
      config.deviceApproved = approved;
      await config.save();
      notifyListeners();
    }
    return status;
  }

  Future<Map<String, dynamic>> info() => api.info();

  Future<List<dynamic>> usuariosDaEmpresa(int empresaId) => api.usuarios(empresaId);

  Future<void> login(int empresaId, int userId, String senha, {String? empresaNome}) async {
    final resp = await api.login(empresaId: empresaId, userId: userId, senha: senha);
    config.token = (resp['token'] ?? '').toString();
    config.empresaId = empresaId;
    if (empresaNome != null) config.empresaNome = empresaNome;
    final user = resp['user'] as Map<String, dynamic>?;
    if (user != null) {
      config.userId = user['id'];
      config.userName = (user['name'] ?? '').toString();
      config.vendedorId = user['vendedor_id'];
    }
    await config.save();
    AppLog.instance.ok('login', 'Entrou como ${config.userName}');
    sync.start();
    notifyListeners();
  }

  Future<void> logout() async {
    sync.stop();
    await api.logout();
    config.clearSession();
    await config.save();
    notifyListeners();
  }

  Future<void> disconnect() async {
    sync.stop();
    config
      ..baseUrl = ''
      ..deviceApproved = false
      ..pairingCode = ''
      ..empresaId = null
      ..empresaNome = ''
      ..clearSession();
    await config.save();
    notifyListeners();
  }
}
