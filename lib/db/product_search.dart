import 'local_db.dart';

class ProductSearch {
  ProductSearch._();

  static Future<List<Map<String, dynamic>>> search(
    LocalDb db,
    String termo, {
    int limit = 200,
  }) async {
    final t = termo.trim();
    if (t.isEmpty) {
      return db.query(
        'SELECT * FROM products WHERE ativo = 1 ORDER BY descricao LIMIT ?',
        [limit],
      );
    }

    final digits = t.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 4) {
      final exact = await db.query(
        '''
        SELECT * FROM products
        WHERE ativo = 1 AND (
          codigo_barras = ? OR codigo = ?
          OR codigo_barras = ? OR codigo = ?
          OR REPLACE(REPLACE(REPLACE(codigo_barras, '.', ''), '-', ''), ' ', '') = ?
        )
        LIMIT ?
        ''',
        [t, t, digits, digits, digits, limit],
      );
      if (exact.isNotEmpty) return exact;
    }

    final like = '%${t.toUpperCase()}%';
    return db.query(
      '''
      SELECT * FROM products
      WHERE ativo = 1 AND (
        descricao LIKE ? OR codigo LIKE ? OR codigo_barras LIKE ? OR marca LIKE ?
      )
      ORDER BY descricao LIMIT ?
      ''',
      [like, like, like, like, limit],
    );
  }
}
