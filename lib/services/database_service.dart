import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/project.dart';
import '../models/pad.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'cm_fx.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        position INTEGER NOT NULL,
        name TEXT NOT NULL,
        image_path TEXT,
        audio_path TEXT,
        color INTEGER NOT NULL,
        volume REAL NOT NULL DEFAULT 1.0,
        playback_rate REAL NOT NULL DEFAULT 1.0,
        is_loop INTEGER NOT NULL DEFAULT 0,
        start_ms INTEGER NOT NULL DEFAULT 0,
        end_ms INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
        'CREATE UNIQUE INDEX idx_project_position ON pads(project_id, position)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration v1 → v2: add audio settings columns
      await db.execute('ALTER TABLE pads ADD COLUMN volume REAL NOT NULL DEFAULT 1.0');
      await db.execute('ALTER TABLE pads ADD COLUMN playback_rate REAL NOT NULL DEFAULT 1.0');
      await db.execute('ALTER TABLE pads ADD COLUMN is_loop INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 3) {
      // Migration v2 → v3: add audio trim (corte) columns
      await db.execute('ALTER TABLE pads ADD COLUMN start_ms INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE pads ADD COLUMN end_ms INTEGER NOT NULL DEFAULT 0');
    }
  }

  // Default colors for new pads (DJ vibe - neon/electronic)
  static const List<int> defaultColors = [
    0xFF7C4DFF, // Deep Purple
    0xFF00BCD4, // Cyan
    0xFFFF4081, // Pink
    0xFF4CAF50, // Green
    0xFFFF9800, // Orange
    0xFF2196F3, // Blue
    0xFFE91E63, // Magenta
    0xFF00E676, // Bright Green
    0xFF7C4DFF, // Deep Purple
    0xFF00BCD4, // Cyan
    0xFFFF4081, // Pink
    0xFF4CAF50, // Green
    0xFFFF9800, // Orange
    0xFF2196F3, // Blue
    0xFFE91E63, // Magenta
    0xFF00E676, // Bright Green
  ];

  Future<int> insertProject(Project project) async {
    final db = await database;
    final id = await db.insert('projects', project.toMap());
    return id;
  }

  Future<List<Project>> getAllProjects() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projects',
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Project.fromMap(maps[i]));
  }

  Future<int> deleteProject(int id) async {
    final db = await database;
    return await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertPad(Pad pad) async {
    final db = await database;
    return await db.insert('pads', pad.toMap());
  }

  Future<List<Pad>> getPadsForProject(int projectId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'pads',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'position ASC',
    );
    return List.generate(maps.length, (i) => Pad.fromMap(maps[i]));
  }

  Future<int> updatePad(Pad pad) async {
    final db = await database;
    return await db.update(
      'pads',
      pad.toMap(),
      where: 'id = ?',
      whereArgs: [pad.id],
    );
  }

  Future<int> savePad(Pad pad) async {
    if (pad.id != null) {
      return await updatePad(pad);
    } else {
      // Fallback: try to find existing by project+position
      final db = await database;
      final existing = await db.query(
        'pads',
        where: 'project_id = ? AND position = ?',
        whereArgs: [pad.projectId, pad.position],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final existingId = existing.first['id'] as int;
        final updatedPad = pad.copyWith(id: existingId);
        return await db.update(
          'pads',
          updatedPad.toMap(),
          where: 'id = ?',
          whereArgs: [existingId],
        );
      } else {
        return await insertPad(pad);
      }
    }
  }

  Future<void> createDefaultPadsForProject(int projectId) async {
    for (int pos = 0; pos < 16; pos++) {
      final pad = Pad(
        projectId: projectId,
        position: pos,
        name: 'Pad ${pos + 1}',
        color: defaultColors[pos % defaultColors.length],
        volume: 1.0,
        playbackRate: 1.0,
        isLoop: false,
      );
      await insertPad(pad);
    }
  }
}
