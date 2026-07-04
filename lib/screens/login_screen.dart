import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/brand.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  List<dynamic> _empresas = [];
  List<dynamic> _users = [];
  int? _empresaId;
  int? _userId;
  final _senha = TextEditingController();
  bool _carregando = true;
  bool _entrando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _senha.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final info = await context.read<AppState>().info();
      _empresas = (info['empresas'] as List?) ?? [];
      if (_empresas.length == 1) {
        _empresaId = _empresas.first['id'];
        await _loadUsers();
      }
    } catch (e) {
      _erro = e.toString();
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _loadUsers() async {
    if (_empresaId == null) return;
    _users = await context.read<AppState>().usuariosDaEmpresa(_empresaId!);
    if (_users.length == 1) _userId = _users.first['id'];
    if (mounted) setState(() {});
  }

  Future<void> _entrar() async {
    if (_empresaId == null || _userId == null) {
      setState(() => _erro = 'Selecione empresa e usuário.');
      return;
    }
    setState(() { _entrando = true; _erro = null; });
    try {
      final emp = _empresas.firstWhere((e) => e['id'] == _empresaId, orElse: () => {});
      await context.read<AppState>().login(
            _empresaId!,
            _userId!,
            _senha.text,
            empresaNome: (emp['nome'] ?? '').toString(),
          );
    } catch (e) {
      setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _entrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: Brand.bg,
      appBar: AppBar(title: const Text('Entrar')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          DropdownButtonFormField<int>(
            value: _empresaId,
            decoration: const InputDecoration(labelText: 'Empresa', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
            items: _empresas.map((e) => DropdownMenuItem(value: e['id'] as int, child: Text((e['nome'] ?? '').toString()))).toList(),
            onChanged: (v) async {
              setState(() { _empresaId = v; _userId = null; });
              await _loadUsers();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _userId,
            decoration: const InputDecoration(labelText: 'Usuário', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
            items: _users.map((u) => DropdownMenuItem(value: u['id'] as int, child: Text((u['name'] ?? '').toString()))).toList(),
            onChanged: (v) => setState(() => _userId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _senha,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Senha do app', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _entrando ? null : _entrar, child: _entrando ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Entrar')),
          if (_erro != null) ...[
            const SizedBox(height: 12),
            Text(_erro!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }
}
