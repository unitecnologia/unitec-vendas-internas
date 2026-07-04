import 'package:flutter/material.dart';

import '../db/local_db.dart';
import 'nova_venda_screen.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
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
      "SELECT * FROM customers WHERE ativo = 1 AND (nome_razao LIKE ? OR codigo LIKE ? OR cpf_cnpj LIKE ?) ORDER BY nome_razao LIMIT 200",
      [like, like, like],
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
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
                final c = _rows[i];
                return ListTile(
                  title: Text((c['nome_razao'] ?? '').toString()),
                  subtitle: Text('${c['codigo'] ?? ''} · ${c['cpf_cnpj'] ?? ''}'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NovaVendaScreen(clienteInicial: c)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
