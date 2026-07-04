import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/brand.dart';

class WaitingApprovalScreen extends StatefulWidget {
  const WaitingApprovalScreen({super.key});

  @override
  State<WaitingApprovalScreen> createState() => _WaitingApprovalScreenState();
}

class _WaitingApprovalScreenState extends State<WaitingApprovalScreen> {
  Timer? _poll;
  String _status = 'pendente';

  @override
  void initState() {
    super.initState();
    _registrar();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _checar());
  }

  Future<void> _registrar() async {
    try {
      await context.read<AppState>().registerDevice();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _checar() async {
    try {
      final s = await context.read<AppState>().refreshApproval();
      if (mounted) setState(() => _status = s);
    } catch (_) {}
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = context.watch<AppState>().config.pairingCode;
    return Scaffold(
      backgroundColor: Brand.bg,
      appBar: AppBar(title: const Text('Autorização')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Peça ao administrador para autorizar este aparelho no ERP (Vendas Internas → Aparelhos).'),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: Brand.surfaceCard(),
              child: Column(
                children: [
                  const Text('Código do aparelho', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 8),
                  Text(code.isEmpty ? '—' : code, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 4)),
                  const SizedBox(height: 16),
                  Text('Status: $_status'),
                ],
              ),
            ),
            const Spacer(),
            TextButton(onPressed: () => context.read<AppState>().disconnect(), child: const Text('Trocar servidor')),
          ],
        ),
      ),
    );
  }
}
