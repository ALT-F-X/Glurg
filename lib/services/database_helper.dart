import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:glurg_app/models/card.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('glurg_cards.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textNullableType = 'TEXT';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE cards (
        id $idType,
        name $textType,
        manaCost $textType,
        manaValue $intType,
        type $textType,
        power $textNullableType,
        toughness $textNullableType,
        oracleText $textType
      )
    ''');

    // Create index on name for faster fuzzy search
    await db.execute('CREATE INDEX idx_card_name ON cards(name)');
  }

  /// Insert a card into the database
  Future<void> insertCard(MtgCard card, String id) async {
    final db = await database;
    await db.insert(
      'cards',
      {
        'id': id,
        'name': card.name,
        'manaCost': card.manaCost,
        'manaValue': card.manaValue,
        'type': card.type,
        'power': card.power,
        'toughness': card.toughness,
        'oracleText': card.oracleText,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple cards in a batch (faster for bulk import)
  Future<void> insertCards(List<Map<String, dynamic>> cards) async {
    final db = await database;
    final batch = db.batch();

    for (final card in cards) {
      batch.insert('cards', card, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  /// Search for a card by name (fuzzy match)
  Future<MtgCard?> searchCardByName(String name) async {
    final db = await database;
    final query = name.trim().toLowerCase();

    // Try exact match first
    final exactResults = await db.query(
      'cards',
      where: 'LOWER(name) = ?',
      whereArgs: [query],
      limit: 1,
    );

    if (exactResults.isNotEmpty) {
      return _cardFromMap(exactResults.first);
    }

    // Try fuzzy match (contains)
    final fuzzyResults = await db.query(
      'cards',
      where: 'LOWER(name) LIKE ?',
      whereArgs: ['%$query%'],
      limit: 5,
    );

    if (fuzzyResults.isNotEmpty) {
      return _cardFromMap(fuzzyResults.first);
    }

    return null;
  }

  /// Get total number of cached cards
  Future<int> getCardCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM cards');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Clear all cards from the database
  Future<void> clearAllCards() async {
    final db = await database;
    await db.delete('cards');
  }

  /// Check if database has any cards
  Future<bool> hasCards() async {
    final count = await getCardCount();
    return count > 0;
  }

  MtgCard _cardFromMap(Map<String, dynamic> map) {
    return MtgCard(
      name: map['name'] as String,
      manaCost: map['manaCost'] as String,
      manaValue: map['manaValue'] as int,
      type: map['type'] as String,
      power: map['power'] as String?,
      toughness: map['toughness'] as String?,
      oracleText: map['oracleText'] as String,
      imageUrl: null, // No images stored offline
      scryfallUrl: null,
    );
  }

  Future close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}
