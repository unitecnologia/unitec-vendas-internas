import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../app_state.dart';
import '../db/local_db.dart';
import '../ui/brand.dart';
import '../ui/format.dart';
import '../ui/item_venda_form_sheet.dart';
import '../ui/selecionar_produto_sheet.dart';

/// Altura extra dos botões de envio (~+1 mm sobre o padrão).
const double _kBtnAltura = 46;

class NovaVendaScreen extends StatefulWidget {
  const NovaVendaScreen({super.key, this.clienteInicial});

  final Map<String, dynamic>? clienteInicial;

  @override
  State<NovaVendaScreen> createState() => _NovaVendaScreenState();
}

class _NovaVendaScreenState extends State<NovaVendaScreen> {
  final _db = LocalDb.instance;
  Map<String, dynamic>? _cliente;
  final List<ViItemVenda> _itens = [];
  final _obs = TextEditingController();
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _cliente = widget.clienteInicial;
  }

  @override
  void dispose() {
    _obs.dispose();
    super.dispose();
  }

  double get _brutoItens => _itens.fold(0.0, (s, i) => s + i.bruto);
  double get _descontoItens => _itens.fold(0.0, (s, i) => s + i.desconto);
  double get _subtotalItens => _itens.fold(0.0, (s, i) => s + i.total);
  double get _total => _subtotalItens;

  Future<void> _escolherCliente() async {
    final rows = await _db.query('SELECT * FROM customers WHERE ativo = 1 ORDER BY nome_razao LIMIT 500');
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

  Future<void> _adicionarItem() async {
    final produto = await showSelecionarProdutoSheet(context);
    if (produto == null || !mounted) return;

    final preco = (produto['preco_venda'] as num?)?.toDouble() ?? 0.0;
    final item = await showItemVendaFormSheet(
      context,
      productId: produto['id'] as int,
      descricao: (produto['descricao'] ?? '').toString(),
      precoUnitario: preco,
    );
    if (item == null || !mounted) return;
    setState(() => _itens.insert(0, item));
  }

  Future<void> _editarItem(int indice) async {
    final item = _itens[indice];
    final atualizado = await showItemVendaFormSheet(
      context,
      productId: item.productId,
      descricao: item.descricao,
      precoUnitario: item.precoUnitario,
      quantidadeInicial: item.quantidade,
      descontoPctInicial: item.descontoPercentualExibicao,
      descontoValorInicial: item.descontoValorExibicao,
      confirmLabel: 'Salvar alterações',
    );
    if (atualizado == null || !mounted) return;
    setState(() => _itens[indice] = atualizado);
  }

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
                  'quantidade': i.quantidade,
                  'preco_unitario': i.precoUnitario,
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
      backgroundColor: Brand.bg,
      appBar: AppBar(
        title: const Text('Nova Venda / Consulta'),
        backgroundColor: Brand.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          ListTile(
            tileColor: Colors.white,
            title: Text(_cliente == null ? 'Selecionar cliente' : (_cliente!['nome_razao'] ?? '').toString()),
            trailing: const Icon(Icons.chevron_right),
            onTap: _escolherCliente,
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color.lerp(Colors.white, Brand.blue, 0.04)!],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Brand.blue.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(color: Brand.blue.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _resumoCompacto('Itens', '${_itens.length}')),
                    Expanded(child: _resumoCompacto('Bruto', brMoney(_brutoItens))),
                    Expanded(child: _resumoCompacto('Produtos', brMoney(_subtotalItens))),
                  ],
                ),
                if (_descontoItens > 0) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _chipResumo('Desc. itens', brMoney(_descontoItens)),
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(height: 1),
                ),
                _resumoRow('Valor total', brMoney(_total), destaque: true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: FilledButton.icon(
              onPressed: _adicionarItem,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Adicionar item'),
              style: FilledButton.styleFrom(
                backgroundColor: Brand.blue,
                minimumSize: const Size.fromHeight(42),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: _itens.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade400),
                        const SizedBox(height: 6),
                        Text('Nenhum item.', style: TextStyle(color: Colors.black.withValues(alpha: 0.45), fontSize: 13)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    itemCount: _itens.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _ItemListaTile(
                      indice: i + 1,
                      item: _itens[i],
                      onTap: () => _editarItem(i),
                      onRemove: () => setState(() => _itens.removeAt(i)),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _obs,
                decoration: const InputDecoration(
                  labelText: 'Observações',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _enviando ? null : () => _enviar('orcamento'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(_kBtnAltura),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _enviando
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Enviar orçamento'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _enviando ? null : () => _enviar('pedido'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Brand.blue,
                        minimumSize: const Size.fromHeight(_kBtnAltura),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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
      ),
    );
  }

  Widget _resumoCompacto(String label, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.black.withValues(alpha: 0.45))),
        const SizedBox(height: 2),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF263238))),
      ],
    );
  }

  Widget _chipResumo(String label, String valor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange.shade800.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $valor',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange.shade800)),
    );
  }

  Widget _resumoRow(String label, String valor, {bool destaque = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontWeight: destaque ? FontWeight.w700 : FontWeight.w500, fontSize: destaque ? 15 : 13)),
        Text(valor,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: destaque ? 16 : 13,
              color: destaque ? Brand.green : const Color(0xFF263238),
            )),
      ],
    );
  }
}

class _ItemListaTile extends StatelessWidget {
  const _ItemListaTile({
    required this.indice,
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  final int indice;
  final ViItemVenda item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  String _fmtQtd(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final temDesconto = item.desconto > 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Brand.blue.withValues(alpha: 0.12)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Brand.blue.withValues(alpha: 0.18), Brand.blue.withValues(alpha: 0.08)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$indice',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Brand.blue, fontSize: 11)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.descricao,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.2)),
                    const SizedBox(height: 3),
                    Text(
                      '${_fmtQtd(item.quantidade)} × ${brMoney(item.precoUnitario)}'
                      '${temDesconto ? '  •  desc. ${brMoney(item.desconto)}' : ''}',
                      style: TextStyle(fontSize: 11, color: Colors.black.withValues(alpha: 0.45)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(brMoney(item.total),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Brand.green)),
                  if (temDesconto)
                    Text(brMoney(item.bruto),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.black.withValues(alpha: 0.35),
                          decoration: TextDecoration.lineThrough,
                        )),
                ],
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: Colors.black.withValues(alpha: 0.25)),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: Colors.redAccent,
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
