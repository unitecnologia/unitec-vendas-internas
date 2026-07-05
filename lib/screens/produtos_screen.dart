import 'package:flutter/material.dart';

import '../db/local_db.dart';
import '../db/product_search.dart';
import '../ui/format.dart';
import '../ui/product_search_field.dart';

class ProdutosScreen extends StatefulWidget {
  const ProdutosScreen({super.key});

  @override
  State<ProdutosScreen> createState() => _ProdutosScreenState();
}

class _ProdutosScreenState extends State<ProdutosScreen> {
  final _db = LocalDb.instance;
  final _busca = TextEditingController();
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _buscar('');
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _buscar(String termo, {bool fromScan = false}) async {
    _rows = await ProductSearch.search(_db, termo, limit: 200);
    if (!mounted) return;
    if (fromScan && _rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produto não encontrado para este código.')),
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Produtos/Consulta')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: ProductSearchField(
              controller: _busca,
              labelText: 'Buscar ou escanear',
              onSearch: _buscar,
              onScan: (code) => _buscar(code, fromScan: true),
            ),
          ),
          Expanded(
            child: _rows.isEmpty
                ? const Center(child: Text('Nenhum produto encontrado.'))
                : ListView.separated(
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = _rows[i];
                      final barras = (p['codigo_barras'] ?? '').toString();
                      return ListTile(
                        title: Text((p['descricao'] ?? '').toString()),
                        subtitle: Text(
                          'Cód. ${p['codigo'] ?? ''}'
                          '${barras.isNotEmpty ? ' · EAN $barras' : ''}'
                          ' · Est.: ${p['estoque'] ?? 0}',
                        ),
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
