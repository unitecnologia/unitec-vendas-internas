import 'package:flutter/material.dart';

import 'barcode_scan_screen.dart';
import 'brand.dart';

class ProductSearchField extends StatelessWidget {
  const ProductSearchField({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onScan,
    this.labelText = 'Buscar produto',
    this.headerStyle = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final Future<void> Function(String code) onScan;
  final String labelText;
  final bool headerStyle;

  Future<void> _escanear(BuildContext context) async {
    final code = await openBarcodeScanner(context);
    if (code == null || code.isEmpty) return;
    controller.text = code;
    await onScan(code);
  }

  @override
  Widget build(BuildContext context) {
    if (headerStyle) {
      return TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: labelText,
          prefixIcon: const Icon(Icons.search, color: Brand.blue),
          suffixIcon: IconButton(
            tooltip: 'Escanear código de barras',
            icon: const Icon(Icons.qr_code_scanner, color: Brand.blue),
            onPressed: () => _escanear(context),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
        textInputAction: TextInputAction.search,
        onChanged: onSearch,
        onSubmitted: onSearch,
      );
    }

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
