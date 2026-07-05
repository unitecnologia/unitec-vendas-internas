import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'unitec_vi.db'),
      version: 3,
      onCreate: (db, _) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE pedidos ADD COLUMN tipo TEXT NOT NULL DEFAULT 'orcamento'");
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE products ADD COLUMN estoque_reservado REAL NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE products ADD COLUMN estoque_disponivel REAL NOT NULL DEFAULT 0');
        }
      },
    );
  }

  Future<void> _createSchema(Database db) async {
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY,
            codigo TEXT, codigo_barras TEXT, descricao TEXT, unidade TEXT,
            marca TEXT, grupo TEXT,
            preco_venda REAL, preco_venda_prazo REAL, preco_atacado REAL, qtd_atacado REAL,
            estoque REAL, estoque_reservado REAL, estoque_disponivel REAL,
            usa_tab_preco INTEGER, mostrar_no_app INTEGER,
            promo_preco_venda REAL, foto_url TEXT, ativo INTEGER, updated_at TEXT
          )''');
        await db.execute('''
          CREATE TABLE customers (
            id INTEGER PRIMARY KEY,
            codigo TEXT, nome_razao TEXT, apelido_fantasia TEXT, cpf_cnpj TEXT,
            limite_credito REAL, ativo INTEGER, updated_at TEXT
          )''');
        await db.execute('''
          CREATE TABLE price_tables (
            id INTEGER PRIMARY KEY, codigo TEXT, descricao TEXT, ativo INTEGER, updated_at TEXT
          )''');
        await db.execute('''
          CREATE TABLE price_table_items (
            id INTEGER PRIMARY KEY, product_id INTEGER, price_table_id INTEGER,
            valor REAL, fator REAL, updated_at TEXT
          )''');
        await db.execute('''
          CREATE TABLE pedidos (
            uuid TEXT PRIMARY KEY,
            tipo TEXT NOT NULL DEFAULT 'orcamento',
            numero TEXT, numero_pedido TEXT, situacao TEXT, total REAL,
            cliente_id INTEGER, cliente_nome TEXT, created_at TEXT, payload_json TEXT
          )''');
        await db.execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)');
  }

  Future<void> upsertAll(String table, List<dynamic> rows, Map<String, dynamic> Function(Map<String, dynamic>) map) async {
    final database = await db;
    final batch = database.batch();
    for (final raw in rows) {
      if (raw is! Map) continue;
      final row = map(Map<String, dynamic>.from(raw));
      batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<int> count(String table) async {
    final r = await (await db).rawQuery('SELECT COUNT(*) AS c FROM $table');
    return (r.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> query(String sql, [List<Object?>? args]) async {
    return (await db).rawQuery(sql, args);
  }

  Future<String?> getMeta(String key) async {
    final r = await (await db).query('meta', where: 'key = ?', whereArgs: [key], limit: 1);
    return r.isEmpty ? null : r.first['value']?.toString();
  }

  Future<void> setMeta(String key, String value) async {
    await (await db).insert('meta', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> upsertPedido(Map<String, dynamic> p) async {
    await (await db).insert(
      'pedidos',
      {
        'uuid': p['uuid'],
        'tipo': p['tipo'] ?? 'orcamento',
        'numero': p['numero'],
        'numero_pedido': p['numero_pedido'],
        'situacao': p['situacao'],
        'total': p['total'],
        'cliente_id': p['cliente_id'],
        'cliente_nome': p['cliente_nome'],
        'created_at': p['created_at'],
        'payload_json': jsonEncode(p),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> listPedidos() async {
    return query('SELECT * FROM pedidos ORDER BY created_at DESC');
  }
}
