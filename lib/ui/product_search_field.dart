import 'package:flutter/material.dart';

import 'barcode_scan_screen.dart';

class ProductSearchField extends StatelessWidget {
  const ProductSearchField({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onScan,
    this.labelText = 'Buscar produto',
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final Future<void> Function(String code) onScan;
  final String labelText;

  Future<void> _escanear(BuildContext context) async {
    final code = await openBarcodeScanner(context);
    if (code == null || code.isEmpty) return;
    controller.text = code;
    await onScan(code);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          tooltip: 'Escanear código de barras',
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: () => _escanear(context),
        ),
        border: const OutlineInputBorder(),
      ),
      textInputAction: TextInputAction.search,
      onChanged: onSearch,
      onSubmitted: onSearch,
    );
  }
}
