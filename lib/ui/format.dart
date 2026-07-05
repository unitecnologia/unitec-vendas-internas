import 'package:flutter/material.dart';

String brMoney(num? value) {
  final v = (value ?? 0).toDouble();
  final fixed = v.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final dec = parts[1];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
    buf.write(intPart[i]);
  }
  return '${v < 0 ? '-' : ''}R\$ ${buf.toString()},$dec';
}

String brDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String fmtEstoque(num? value) {
  final v = (value ?? 0).toDouble();
  return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
}

double estoqueAtual(Map<String, dynamic> p) =>
    (p['estoque'] as num?)?.toDouble() ?? 0;

double estoqueReservado(Map<String, dynamic> p) =>
    (p['estoque_reservado'] as num?)?.toDouble() ?? 0;

double estoqueDisponivel(Map<String, dynamic> p) =>
    estoqueAtual(p) - estoqueReservado(p);

String situacaoLabel(String? s) => switch (s) {
      'aguardando' => 'Aguardando PDV',
      'pendente' => 'Pendente (Monitor)',
      'no_caixa' => 'No caixa',
      'faturado' => 'Faturado',
      'pago' => 'Pago',
      'cancelado' => 'Cancelado',
      _ => s ?? '—',
    };

String tipoLabel(String? tipo) => switch (tipo) {
      'pedido' => 'Pedido',
      'orcamento' => 'Orçamento',
      _ => tipo ?? 'Orçamento',
    };

/// Cores de status (orçamento e pedido usam a mesma regra).
({Color background, Color foreground}) situacaoCores(String? s) => switch (s) {
      'faturado' || 'pago' => (
          background: const Color(0xFF16A34A),
          foreground: const Color(0xFFFFFFFF),
        ),
      'aguardando' || 'pendente' || 'no_caixa' => (
          background: const Color(0xFFFACC15),
          foreground: const Color(0xFF713F12),
        ),
      'cancelado' => (
          background: const Color(0xFFFEE2E2),
          foreground: const Color(0xFFB91C1C),
        ),
      _ => (
          background: const Color(0xFFE5E7EB),
          foreground: const Color(0xFF374151),
        ),
    };
