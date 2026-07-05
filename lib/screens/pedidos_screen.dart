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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _carregando = true);
    await context.read<AppState>().sync.syncNow();
    _rows = await LocalDb.instance.listPedidos();
    if (mounted) setState(() => _carregando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus Pedidos')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _rows.isEmpty
                  ? ListView(children: const [SizedBox(height: 120), Center(child: Text('Nenhum pedido ainda.'))])
                  : ListView.separated(
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final r = _rows[i];
                        final dav = (r['numero'] ?? '—').toString();
                        final ped = (r['numero_pedido'] ?? '').toString();
                        final tipo = r['tipo']?.toString() ?? 'orcamento';
                        return ListTile(
                          title: Text('${tipoLabel(tipo)} · DAV $dav${ped.isNotEmpty ? ' · Ped. $ped' : ''}'),
                          subtitle: Text('${r['cliente_nome'] ?? ''}\n${situacaoLabel(r['situacao']?.toString())} · ${brDate(r['created_at']?.toString())}'),
                          isThreeLine: true,
                          trailing: Text(brMoney(r['total']), style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
            ),
    );
  }
}
