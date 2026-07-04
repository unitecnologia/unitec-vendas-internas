import 'dart:async';
import 'dart:io';

import '../api/api_client.dart';
import '../log/app_log.dart';

class ServerDiscovery {
  static const List<int> defaultPorts = [8765, 8000];
  static const int batchSize = 16;

  static Future<String?> find({void Function(int done, int total)? onProgress}) async {
    final prefixes = await _localPrefixes();
    if (prefixes.isEmpty) return null;

    for (final prefix in prefixes) {
      const total = 254;
      var done = 0;
      for (var start = 1; start <= total; start += batchSize) {
        final end = (start + batchSize - 1).clamp(1, total);
        final futures = <Future<String?>>[];
        for (var host = start; host <= end; host++) {
          futures.add(_probeHost('$prefix.$host', defaultPorts));
        }
        final results = await Future.wait(futures);
        done += (end - start + 1);
        onProgress?.call(done, total);
        for (final r in results) {
          if (r != null) return r;
        }
      }
    }
    return null;
  }

  static Future<List<String>> _localPrefixes() async {
    final prefixes = <String>{};
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.') || ip.startsWith('10.')) {
            final parts = ip.split('.');
            if (parts.length == 4) prefixes.add('${parts[0]}.${parts[1]}.${parts[2]}');
          }
        }
      }
    } catch (e) {
      AppLog.instance.error('rede', e.toString());
    }
    return prefixes.toList();
  }

  static Future<String?> _probeHost(String ip, List<int> ports) async {
    for (final port in ports) {
      Socket? socket;
      try {
        socket = await Socket.connect(ip, port, timeout: const Duration(milliseconds: 600));
      } catch (_) {
        continue;
      } finally {
        socket?.destroy();
      }
      final base = 'http://$ip:$port';
      if (await ApiClient.pingBase(base)) return base;
    }
    return null;
  }
}
