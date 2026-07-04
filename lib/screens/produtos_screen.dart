import 'package:flutter/material.dart';

import '../db/local_db.dart';
import '../ui/format.dart';

class ProdutosScreen extends StatefulWidget {
  const ProdutosScreen({super.key});

  @override
  State<ProdutosScreen> createState() => _ProdutosScreenState();
}

class _ProdutosScreenState extends State<ProdutosScreen> {
  final _db = LocalDb.instance;
  List<Map<String, dynamic>> _rows = [];
  String _termo = '';

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  Future<void> _buscar() async {
    final like = '%${_termo.toUpperCase()}%';
    _rows = await _db.query(
      "SELECT * FROM products WHERE ativo = 1 AND (descricao LIKE ? OR codigo LIKE ? OR codigo_barras LIKE ?) ORDER BY descricao LIMIT 200",
      [like, like, like],
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consultar Produto')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(labelText: 'Buscar', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
              onChanged: (v) {
                _termo = v;
                _buscar();
              },
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = _rows[i];
                return ListTile(
                  title: Text((p['descricao'] ?? '').toString()),
                  subtitle: Text('Cód. ${p['codigo'] ?? ''} · Est.: ${p['estoque'] ?? 0}'),
                  trailing: Text(brMoney(p['preco_venda']), style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
