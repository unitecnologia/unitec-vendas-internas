import 'package:flutter/foundation.dart';

/// Portas do servidor ERP usadas na conexão e na varredura de rede.
class ServerPorts {
  static const int productionPort = 8765;
  static const int devPort = 8000;

  /// Em debug (build de desenvolvimento) testa 8000 antes de 8765.
  static List<int> get discoveryOrder =>
      kDebugMode ? [devPort, productionPort] : [productionPort, devPort];

  static int get defaultPort => discoveryOrder.first;

  /// Monta URLs candidatas para um IP/host (com ou sem porta explícita).
  static List<String> connectionCandidates(String input) {
    var raw = input.trim();
    if (raw.isEmpty) return [];

    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'http://$raw';
    }
    raw = raw.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) return [raw];

    final host = uri.host;
    final explicitPort = uri.hasPort && uri.port != 0 ? uri.port : null;

    final ports = <int>[];
    if (explicitPort != null) ports.add(explicitPort);
    for (final p in discoveryOrder) {
      if (!ports.contains(p)) ports.add(p);
    }
    return ports.map((p) => 'http://$host:$p').toList();
  }
}
