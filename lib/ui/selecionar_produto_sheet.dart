import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../db/local_db.dart';
import '../db/product_search.dart';
import 'brand.dart';
import 'product_search_field.dart';
import 'produto_list_card.dart';

/// Modal de seleção de produto (padrão FV) com busca, grupos e scanner.
Future<Map<String, dynamic>?> showSelecionarProdutoSheet(BuildContext context) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const SelecionarProdutoSheet(),
  );
}

class SelecionarProdutoSheet extends StatefulWidget {
  const SelecionarProdutoSheet({super.key});

  @override
  State<SelecionarProdutoSheet> createState() => _SelecionarProdutoSheetState();
}

class _SelecionarProdutoSheetState extends State<SelecionarProdutoSheet> {
  final _db = LocalDb.instance;
  final _busca = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  List<String> _grupos = [];
  String _termo = '';
  String? _grupoSel;

  @override
  void initState() {
    super.initState();
    _carregarGrupos();
    _buscar();
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _carregarGrupos() async {
    final rows = await _db.query(
      "SELECT DISTINCT grupo FROM products WHERE ativo = 1 "
      "AND grupo IS NOT NULL AND TRIM(grupo) <> '' ORDER BY grupo",
    );
    if (mounted) {
      setState(() {
        _grupos = rows.map((r) => (r['grupo'] ?? '').toString()).where((g) => g.isNotEmpty).toList();
      });
    }
  }

  Future<void> _buscar() async {
    List<Map<String, dynamic>> rows;
    if (_grupoSel != null) {
      final like = '%${_termo.trim()}%';
      rows = await _db.query(
        "SELECT * FROM products WHERE ativo = 1 AND grupo = ? "
        "AND (descricao LIKE ? OR codigo LIKE ? OR codigo_barras LIKE ? OR marca LIKE ?) "
        'ORDER BY descricao LIMIT 100',
        [_grupoSel, like, like, like, like],
      );
    } else {
      rows = await ProductSearch.search(_db, _termo, limit: 100);
    }
    if (mounted) setState(() => _rows = rows);
  }

  Future<void> _aplicarScan(String code) async {
    final rows = await ProductSearch.search(_db, code, limit: 100);
    if (!mounted) return;
    if (rows.length == 1) {
      Navigator.pop(context, rows.first);
      return;
    }
    _termo = code;
    _busca.text = code;
    setState(() => _rows = rows);
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produto não encontrado para este código.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = context.read<AppState>().config.baseUrl;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 1.0,
      minChildSize: 0.6,
      maxChildSize: 1.0,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Brand.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 2),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 6, 2),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Selecionar produto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: ProductSearchField(
                    controller: _busca,
                    labelText: 'Buscar...',
                    onSearch: (s) {
                      _termo = s;
                      _buscar();
                    },
                    onScan: _aplicarScan,
                  ),
                ),
                if (_grupos.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _chip('Todos', _grupoSel == null, () {
                          setState(() => _grupoSel = null);
                          _buscar();
                        }),
                        for (final g in _grupos)
                          _chip(g, _grupoSel == g, () {
                            setState(() => _grupoSel = g);
                            _buscar();
                          }),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Expanded(
                  child: _rows.isEmpty
                      ? const Center(child: Text('Nada encontrado.'))
                      : ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                          itemCount: _rows.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final p = _rows[i];
                            return ProdutoListCard(
                              produto: p,
                              baseUrl: base,
                              onTap: () => Navigator.pop(context, p),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => onTap(),
        selectedColor: Brand.blue,
        labelStyle: TextStyle(
          color: sel ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }
}
