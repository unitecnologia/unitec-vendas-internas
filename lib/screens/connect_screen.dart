import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_info.dart';
import '../app_state.dart';
import '../net/discovery.dart';
import '../ui/brand.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _ipCtrl = TextEditingController();
  bool _buscando = false;
  bool _conectando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().ensureDeviceIdentity();
    final last = context.read<AppState>().config.lastBaseUrl;
    if (last.isNotEmpty) _ipCtrl.text = last.replaceFirst(RegExp(r'^https?://'), '');
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    setState(() { _buscando = true; _erro = null; });
    try {
      final found = await ServerDiscovery.find();
      if (!mounted) return;
      if (found == null) {
        setState(() { _erro = 'Servidor não encontrado. Digite o IP manualmente.'; _buscando = false; });
        return;
      }
      await context.read<AppState>().connectFound(found);
    } catch (e) {
      if (mounted) setState(() { _erro = e.toString(); _buscando = false; });
    }
  }

  Future<void> _conectar() async {
    setState(() { _conectando = true; _erro = null; });
    try {
      await context.read<AppState>().connectManual(_ipCtrl.text);
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _conectando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _buscando || _conectando;
    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(kAppName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Brand.textPrimary)),
              Text('v$kAppVersion', style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 32),
              TextField(
                controller: _ipCtrl,
                decoration: const InputDecoration(
                  labelText: 'IP do servidor',
                  hintText: '192.168.0.10:8765',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                enabled: !busy,
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: busy ? null : _conectar, child: _conectando ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Conectar')),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: busy ? null : _buscar, child: _buscando ? const Text('Buscando...') : const Text('Buscar na rede')),
              if (_erro != null) ...[
                const SizedBox(height: 16),
                Text(_erro!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
