import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/attendance.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('attendance.db');
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

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE attendance (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        check_in_time TEXT NOT NULL,
        check_out_time TEXT,
        status TEXT NOT NULL,
        photo_url TEXT
      )
    ''');
  }

  Future<int> insertAttendance(Attendance attendance) async {
    final db = await instance.database;
    return await db.insert(
      'attendance',
      {
        'id': attendance.id,
        'employee_id': attendance.employeeId,
        'check_in_time': attendance.checkInTime.toIso8601String(),
        'check_out_time': attendance.checkOutTime?.toIso8601String(),
        'status': attendance.status,
        'photo_url': attendance.photoUrl,
      },
    );
  }

  Future<List<Attendance>> getAttendanceByEmployee(String employeeId) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'check_in_time DESC',
    );

    return List.generate(maps.length, (i) {
      return Attendance(
        id: maps[i]['id'],
        employeeId: maps[i]['employee_id'],
        checkInTime: DateTime.parse(maps[i]['check_in_time']),
        checkOutTime: maps[i]['check_out_time'] != null
            ? DateTime.parse(maps[i]['check_out_time'])
            : null,
        status: maps[i]['status'],
        photoUrl: maps[i]['photo_url'],
      );
    });
  }
}
