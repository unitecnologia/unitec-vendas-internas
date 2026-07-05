import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../db/local_db.dart';
import '../ui/format.dart';

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _carregando = true;
  String _filtroTipo = 'todos';

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_filtroTipo == 'todos') return _rows;
    return _rows.where((r) => (r['tipo']?.toString() ?? 'orcamento') == _filtroTipo).toList();
  }

  int _contagem(String tipo) {
    if (tipo == 'todos') return _rows.length;
    return _rows.where((r) => (r['tipo']?.toString() ?? 'orcamento') == tipo).length;
  }

  Future<void> _load() async {
    setState(() => _carregando = true);
    await context.read<AppState>().sync.syncNow();
    _rows = await LocalDb.instance.listPedidos();
    if (mounted) setState(() => _carregando = false);
  }

  Widget _filtroChip(String value, String label) {
    final qtd = _contagem(value);
    return ChoiceChip(
      label: Text('$label ($qtd)'),
      selected: _filtroTipo == value,
      onSelected: (_) => setState(() => _filtroTipo = value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = _filtrados;

    return Scaffold(
      appBar: AppBar(title: const Text('Meus Pedidos / Orçamento')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _filtroChip('todos', 'Todos'),
                _filtroChip('orcamento', 'Orçamentos'),
                _filtroChip('pedido', 'Pedidos'),
              ],
            ),
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: lista.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Text(
                                  _filtroTipo == 'orcamento'
                                      ? 'Nenhum orçamento ainda.'
                                      : _filtroTipo == 'pedido'
                                          ? 'Nenhum pedido ainda.'
                                          : 'Nenhum documento ainda.',
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            itemCount: lista.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) => _PedidoTile(row: lista[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PedidoTile extends StatelessWidget {
  const _PedidoTile({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final dav = (row['numero'] ?? '—').toString();
    final ped = (row['numero_pedido'] ?? '').toString();
    final tipo = row['tipo']?.toString() ?? 'orcamento';
    final situacao = row['situacao']?.toString();
    final cores = situacaoCores(situacao);

    return ListTile(
      title: Text('${tipoLabel(tipo)} · DAV $dav${ped.isNotEmpty ? ' · Ped. $ped' : ''}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text((row['cliente_nome'] ?? '').toString()),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cores.background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  situacaoLabel(situacao),
                  style: TextStyle(
                    color: cores.foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(brDate(row['created_at']?.toString()), style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ],
      ),
      isThreeLine: true,
      trailing: Text(brMoney(row['total']), style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
