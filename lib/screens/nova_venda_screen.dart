import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../app_state.dart';
import '../db/local_db.dart';
import '../db/product_search.dart';
import '../ui/brand.dart';
import '../ui/format.dart';
import '../ui/product_search_field.dart';

class NovaVendaScreen extends StatefulWidget {
  const NovaVendaScreen({super.key, this.clienteInicial});

  final Map<String, dynamic>? clienteInicial;

  @override
  State<NovaVendaScreen> createState() => _NovaVendaScreenState();
}

class _Item {
  _Item({required this.productId, required this.descricao, required this.qtd, required this.preco, this.desconto = 0});
  final int productId;
  final String descricao;
  double qtd;
  final double preco;
  double desconto;
  double get total => (qtd * preco) - desconto;
}

class _NovaVendaScreenState extends State<NovaVendaScreen> {
  final _db = LocalDb.instance;
  Map<String, dynamic>? _cliente;
  final List<_Item> _itens = [];
  final _obs = TextEditingController();
  final _busca = TextEditingController();
  List<Map<String, dynamic>> _produtos = [];
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _cliente = widget.clienteInicial;
    _buscarProdutos('');
  }

  @override
  void dispose() {
    _obs.dispose();
    _busca.dispose();
    super.dispose();
  }

  Future<void> _buscarProdutos(String termo, {bool fromScan = false}) async {
    final rows = await ProductSearch.search(_db, termo, limit: 40);
    if (!mounted) return;

    if (fromScan && rows.length == 1) {
      _addProduto(rows.first);
      _busca.clear();
      _produtos = await ProductSearch.search(_db, '', limit: 40);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${rows.first['descricao']} adicionado')),
      );
    } else if (fromScan && rows.isEmpty) {
      _produtos = rows;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produto não encontrado para este código.')),
      );
    } else {
      _produtos = rows;
    }
    setState(() {});
  }

  Future<void> _escolherCliente() async {
    final rows = await _db.query("SELECT * FROM customers WHERE ativo = 1 ORDER BY nome_razao LIMIT 500");
    if (!mounted) return;
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        var filtro = '';
        return StatefulBuilder(
          builder: (ctx, setSt) {
            final list = rows.where((c) {
              if (filtro.isEmpty) return true;
              final t = filtro.toUpperCase();
              return (c['nome_razao'] ?? '').toString().toUpperCase().contains(t);
            }).toList();
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              builder: (_, sc) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Buscar cliente', border: OutlineInputBorder()),
                      onChanged: (v) => setSt(() => filtro = v),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: sc,
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final c = list[i];
                        return ListTile(
                          title: Text((c['nome_razao'] ?? '').toString()),
                          subtitle: Text((c['codigo'] ?? '').toString()),
                          onTap: () => Navigator.pop(ctx, c),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (picked != null) setState(() => _cliente = picked);
  }

  void _addProduto(Map<String, dynamic> p) {
    setState(() {
      _itens.add(_Item(
        productId: p['id'] as int,
        descricao: (p['descricao'] ?? '').toString(),
        qtd: 1,
        preco: (p['preco_venda'] as num?)?.toDouble() ?? 0,
      ));
    });
  }

  double get _total => _itens.fold(0.0, (s, i) => s + i.total);

  Future<void> _enviar(String tipo) async {
    if (_cliente == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um cliente.')));
      return;
    }
    if (_itens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adicione pelo menos um item.')));
      return;
    }
    setState(() => _enviando = true);
    try {
      final uuid = const Uuid().v4();
      final state = context.read<AppState>();
      final order = {
        'uuid': uuid,
        'tipo': tipo,
        'device_uuid': state.config.deviceUuid,
        'cliente_id': _cliente!['id'],
        'cliente_nome': _cliente!['nome_razao'],
        'observacoes': _obs.text.trim().isEmpty ? null : _obs.text.trim(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'total': _total,
        'itens': _itens
            .map((i) => {
                  'product_id': i.productId,
                  'descricao': i.descricao,
                  'quantidade': i.qtd,
                  'preco_unitario': i.preco,
                  'desconto': i.desconto,
                })
            .toList(),
      };
      final resp = await state.sync.enviarVenda(order);
      if (!mounted) return;
      final isPedido = tipo == 'pedido';
      final numero = resp['numero'] ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPedido
                ? 'Pedido $numero enviado ao Monitor de Vendas.'
                : 'Orçamento $numero enviado. Aguardando PDV.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova Venda / Consulta')),
      body: Column(
        children: [
          ListTile(
            title: Text(_cliente == null ? 'Selecionar cliente' : (_cliente!['nome_razao'] ?? '').toString()),
            trailing: const Icon(Icons.chevron_right),
            onTap: _escolherCliente,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ProductSearchField(
              controller: _busca,
              labelText: 'Buscar produto',
              onSearch: (v) => _buscarProdutos(v),
              onScan: (code) => _buscarProdutos(code, fromScan: true),
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _produtos.length,
              itemBuilder: (_, i) {
                final p = _produtos[i];
                return Padding(
                  padding: const EdgeInsets.all(6),
                  child: InkWell(
                    onTap: () => _addProduto(p),
                    child: Container(
                      width: 140,
                      padding: const EdgeInsets.all(8),
                      decoration: Brand.surfaceCard(radius: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((p['descricao'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text(brMoney(p['preco_venda']), style: const TextStyle(color: Brand.blue, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _itens.length,
              itemBuilder: (_, i) {
                final item = _itens[i];
                return ListTile(
                  title: Text(item.descricao),
                  subtitle: Text('${item.qtd} x ${brMoney(item.preco)}'),
                  trailing: Text(brMoney(item.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                  onLongPress: () => setState(() => _itens.removeAt(i)),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(controller: _obs, decoration: const InputDecoration(labelText: 'Observações', border: OutlineInputBorder()), maxLines: 2),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Total: ${brMoney(_total)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _enviando ? null : () => _enviar('orcamento'),
                        child: _enviando
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Enviar orçamento'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: _enviando ? null : () => _enviar('pedido'),
                        child: _enviando
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Enviar pedido'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
