import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LogLevel { info, ok, warn, error }

class LogEntry {
  LogEntry(this.time, this.level, this.tag, this.message);

  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;
}

class AppLog extends ChangeNotifier {
  AppLog._();

  static final AppLog instance = AppLog._();

  static const _key = 'unitec_vi_log';
  static const _max = 400;

  final List<LogEntry> _entries = [];

  List<LogEntry> get entries => _entries.reversed.toList(growable: false);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _entries
          ..clear()
          ..addAll(list.map((e) {
            final j = Map<String, dynamic>.from(e as Map);
            return LogEntry(
              DateTime.tryParse(j['t']?.toString() ?? '') ?? DateTime.now(),
              LogLevel.values.firstWhere((v) => v.name == j['l'], orElse: () => LogLevel.info),
              (j['g'] ?? '').toString(),
              (j['m'] ?? '').toString(),
            );
          }));
      }
    } catch (_) {}
    notifyListeners();
  }

  void info(String tag, String m) => _add(LogLevel.info, tag, m);
  void ok(String tag, String m) => _add(LogLevel.ok, tag, m);
  void warn(String tag, String m) => _add(LogLevel.warn, tag, m);
  void error(String tag, String m) => _add(LogLevel.error, tag, m);

  void _add(LogLevel level, String tag, String message) {
    _entries.add(LogEntry(DateTime.now(), level, tag, message));
    if (_entries.length > _max) {
      _entries.removeRange(0, _entries.length - _max);
    }
    notifyListeners();
  }
}
