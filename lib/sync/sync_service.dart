import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../db/local_db.dart';
import '../log/app_log.dart';

enum SyncStatus { idle, syncing, ok, offline, error }

class SyncService extends ChangeNotifier {
  SyncService(this.config, this.api);

  final AppConfig config;
  final ApiClient api;
  final LocalDb _db = LocalDb.instance;

  Timer? _timer;
  SyncStatus status = SyncStatus.idle;
  String? lastError;
  DateTime? lastSyncAt;

  void start() {
    stop();
    syncNow();
    _scheduleNext();
  }

  void _scheduleNext() {
    final jitter = Duration(milliseconds: Random().nextInt(5000));
    _timer = Timer(const Duration(seconds: 30) + jitter, () async {
      await syncNow();
      _scheduleNext();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> syncNow() async {
    if (!config.isLoggedIn) return;
    status = SyncStatus.syncing;
    notifyListeners();
    try {
      await _pull().timeout(const Duration(seconds: 60));
      lastSyncAt = DateTime.now();
      config.lastSyncIso = lastSyncAt!.toUtc().toIso8601String();
      await config.save();
      status = SyncStatus.ok;
      lastError = null;
    } on TimeoutException {
      status = SyncStatus.offline;
      lastError = 'Tempo esgotado';
    } on ApiException catch (e) {
      status = SyncStatus.error;
      lastError = e.message;
    } catch (e) {
      status = SyncStatus.offline;
      lastError = e.toString();
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> enviarOrcamento(Map<String, dynamic> order) async {
    final resp = await api.push([order]);
    final results = (resp['results'] as List?) ?? [];
    if (results.isEmpty) throw ApiException('Resposta vazia do servidor');
    final first = Map<String, dynamic>.from(results.first as Map);
    if (first['status'] == 'erro') {
      throw ApiException((first['erro'] ?? 'Erro ao enviar').toString());
    }
    await _db.upsertPedido({
      'uuid': first['uuid'] ?? order['uuid'],
      'numero': first['numero'],
      'numero_pedido': first['numero_pedido'],
      'situacao': first['situacao'] ?? 'aguardando',
      'total': first['total'] ?? order['total'],
      'cliente_id': order['cliente_id'],
      'cliente_nome': order['cliente_nome'],
      'created_at': order['created_at'],
    });
    await syncNow();
    return first;
  }

  Future<void> _pull() async {
    final etag = await _db.getMeta('pull_etag');
    final data = await api.pull(etag: etag);
    if (data == null) return;

    await _db.upsertAll('products', data['products'] ?? [], (r) => {
          'id': r['id'],
          'codigo': r['codigo'],
          'codigo_barras': r['codigo_barras'],
          'descricao': r['descricao'],
          'unidade': r['unidade'],
          'marca': r['marca'],
          'grupo': r['grupo'],
          'preco_venda': _d(r['preco_venda']),
          'preco_venda_prazo': _d(r['preco_venda_prazo']),
          'preco_atacado': _d(r['preco_atacado']),
          'qtd_atacado': _d(r['qtd_atacado']),
          'estoque': _d(r['estoque']),
          'usa_tab_preco': _b(r['usa_tab_preco']),
          'mostrar_no_app': _b(r['mostrar_no_app']),
          'promo_preco_venda': _d(r['promo_preco_venda']),
          'foto_url': r['foto_url'],
          'ativo': _b(r['ativo']),
          'updated_at': r['updated_at'],
        });

    await _db.upsertAll('customers', data['customers'] ?? [], (r) => {
          'id': r['id'],
          'codigo': r['codigo'],
          'nome_razao': r['nome_razao'],
          'apelido_fantasia': r['apelido_fantasia'],
          'cpf_cnpj': r['cpf_cnpj'],
          'limite_credito': _d(r['limite_credito']),
          'ativo': _b(r['ativo']),
          'updated_at': r['updated_at'],
        });

    await _db.upsertAll('price_tables', data['price_tables'] ?? [], (r) => {
          'id': r['id'],
          'codigo': r['codigo'],
          'descricao': r['descricao'],
          'ativo': _b(r['ativo']),
          'updated_at': r['updated_at'],
        });

    await _db.upsertAll('price_table_items', data['price_table_items'] ?? [], (r) => {
          'id': r['id'],
          'product_id': r['product_id'],
          'price_table_id': r['price_table_id'],
          'valor': _d(r['valor']),
          'fator': _d(r['fator']),
          'updated_at': r['updated_at'],
        });

    for (final raw in (data['pedidos'] as List?) ?? []) {
      if (raw is! Map) continue;
      final p = Map<String, dynamic>.from(raw);
      await _db.upsertPedido({
        'uuid': p['uuid'],
        'numero': p['numero'],
        'numero_pedido': p['numero_pedido'],
        'situacao': p['situacao'],
        'total': p['total'],
        'cliente_id': p['cliente_id'],
        'cliente_nome': p['cliente_nome'],
        'created_at': p['created_at'],
      });
    }

    final newEtag = data['_etag']?.toString();
    if (newEtag != null && newEtag.isNotEmpty) {
      await _db.setMeta('pull_etag', newEtag.replaceAll('"', ''));
    }
    AppLog.instance.ok('sync', 'Catálogo atualizado');
  }

  double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
  int _b(dynamic v) => v == true || v == 1 ? 1 : 0;
}
