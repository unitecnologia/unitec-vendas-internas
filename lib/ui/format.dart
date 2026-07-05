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
