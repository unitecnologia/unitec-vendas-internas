import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../db/local_db.dart';
import '../sync/sync_service.dart';
import '../ui/brand.dart';
import '../ui/home_menu_card.dart';
import 'clientes_screen.dart';
import 'nova_venda_screen.dart';
import 'pedidos_screen.dart';
import 'produtos_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _produtos = 0;
  int _clientes = 0;
  int _pedidos = 0;

  @override
  void initState() {
    super.initState();
    _contadores();
  }

  Future<void> _contadores() async {
    final db = LocalDb.instance;
    final ped = await db.listPedidos();
    if (mounted) {
      setState(() {
        _produtos = 0;
        _clientes = 0;
        _pedidos = ped.length;
      });
    }
    final pr = await db.count('products');
    final cl = await db.count('customers');
    if (mounted) setState(() { _produtos = pr; _clientes = cl; });
  }

  Future<void> _abrir(Widget tela) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => tela));
    await _contadores();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return ListenableBuilder(
      listenable: state.sync,
      builder: (context, _) {
        final sync = state.sync;
        return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await state.sync.syncNow();
            await _contadores();
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Olá, ${state.config.userName}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Brand.textPrimary)),
                      Text(state.config.empresaNome, style: const TextStyle(color: Colors.black54)),
                      const SizedBox(height: 8),
                      Text(
                        sync.status == SyncStatus.syncing
                            ? 'Sincronizando...'
                            : sync.lastError != null
                                ? sync.lastError!
                                : 'Online — orçamentos vão para o PDV',
                        style: TextStyle(color: sync.lastError != null ? Colors.red : Colors.black54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.15),
                  delegate: SliverChildListDelegate([
                    HomeMenuCard(label: 'Nova Venda', icon: Icons.point_of_sale_rounded, color: Brand.blue, onTap: () => _abrir(const NovaVendaScreen()), badge: null),
                    HomeMenuCard(label: 'Meus Pedidos', icon: Icons.receipt_long_rounded, color: const Color(0xFF6366F1), onTap: () => _abrir(const PedidosScreen()), badge: _pedidos > 0 ? '$_pedidos' : null),
                    HomeMenuCard(label: 'Clientes', icon: Icons.people_alt_rounded, color: Brand.green, onTap: () => _abrir(const ClientesScreen())),
                    HomeMenuCard(label: 'Produtos', icon: Icons.inventory_2_rounded, color: const Color(0xFF2563EB), onTap: () => _abrir(const ProdutosScreen())),
                  ]),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _chip('Produtos', '$_produtos'),
                      const SizedBox(width: 8),
                      _chip('Clientes', '$_clientes'),
                      const Spacer(),
                      TextButton.icon(onPressed: () => state.sync.syncNow(), icon: const Icon(Icons.sync), label: const Text('Sync')),
                      TextButton(onPressed: () => state.logout(), child: const Text('Sair')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Text('$label: $value', style: const TextStyle(fontSize: 12)),
    );
  }
}
