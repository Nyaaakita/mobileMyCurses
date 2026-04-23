import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:sqflite/sqflite.dart";

import "../models.dart";

/// Локальная SQLite-кэш (аналог Drift без codegen).
class LmsDb {
  LmsDb._();
  static Database? _db;

  static Future<void> _ensureStartedCoursesSchema(Database db) async {
    final info = await db.rawQuery("PRAGMA table_info(started_courses)");
    if (info.isEmpty) return;
    var courseIdIsPrimary = false;
    var hasUserKey = false;
    for (final row in info) {
      final name = (row["name"] ?? "").toString();
      if (name == "course_id" && (row["pk"] as int? ?? 0) == 1) {
        courseIdIsPrimary = true;
      }
      if (name == "user_key") {
        hasUserKey = true;
      }
    }
    if (!courseIdIsPrimary && hasUserKey) return;

    await db.execute("ALTER TABLE started_courses RENAME TO started_courses_old");
    await db.execute("""
      CREATE TABLE started_courses (
        user_key TEXT NOT NULL,
        course_id TEXT NOT NULL,
        started_at TEXT NOT NULL
      )
    """);
    await db.execute("""
      CREATE UNIQUE INDEX idx_started_courses_user_course
      ON started_courses (user_key, course_id)
    """);
    if (hasUserKey) {
      await db.execute("""
        INSERT OR IGNORE INTO started_courses (user_key, course_id, started_at)
        SELECT COALESCE(NULLIF(user_key, ''), 'legacy'), course_id, started_at
        FROM started_courses_old
      """);
    } else {
      await db.execute("""
        INSERT OR IGNORE INTO started_courses (user_key, course_id, started_at)
        SELECT 'legacy', course_id, started_at
        FROM started_courses_old
      """);
    }
    await db.execute("DROP TABLE started_courses_old");
  }

  static Future<Database> instance() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, "lms.db");
    _db = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute("""
          CREATE TABLE courses (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            difficulty TEXT NOT NULL,
            estimated_minutes INTEGER NOT NULL,
            content_version INTEGER NOT NULL,
            progress_percent INTEGER NOT NULL DEFAULT 0,
            cached_at TEXT NOT NULL
          )
        """);
        await db.execute("""
          CREATE TABLE lessons (
            id TEXT PRIMARY KEY,
            course_id TEXT NOT NULL,
            title TEXT NOT NULL,
            order_index INTEGER NOT NULL,
            ui_status TEXT NOT NULL,
            content_version INTEGER NOT NULL DEFAULT 1,
            blocks_json TEXT,
            cached_at TEXT NOT NULL
          )
        """);
        await db.execute("""
          CREATE TABLE sync_queue (
            event_id TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        """);
        await db.execute("""
          CREATE TABLE started_courses (
            user_key TEXT NOT NULL,
            course_id TEXT NOT NULL,
            started_at TEXT NOT NULL
          )
        """);
        await db.execute("""
          CREATE UNIQUE INDEX idx_started_courses_user_course
          ON started_courses (user_key, course_id)
        """);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("""
            CREATE TABLE started_courses (
              user_key TEXT NOT NULL,
              course_id TEXT NOT NULL,
              started_at TEXT NOT NULL
            )
          """);
          await db.execute("""
            CREATE UNIQUE INDEX idx_started_courses_user_course
            ON started_courses (user_key, course_id)
          """);
        }
        if (oldVersion < 3) {
          await _ensureStartedCoursesSchema(db);
        }
      },
    );
    await _ensureStartedCoursesSchema(_db!);
    return _db!;
  }

  static Future<List<Course>> getCourses() async {
    final db = await instance();
    final rows = await db.query("courses", orderBy: "cached_at DESC");
    return rows.map(_courseFromRow).toList();
  }

  static Course _courseFromRow(Map<String, Object?> r) {
    return Course(
      id: r["id"]! as String,
      title: r["title"]! as String,
      description: r["description"]! as String,
      difficulty: r["difficulty"]! as String,
      estimatedMinutes: r["estimated_minutes"]! as int,
      contentVersion: r["content_version"]! as int,
      progressPercent: r["progress_percent"]! as int,
    );
  }

  static Future<void> upsertCourses(List<Course> list) async {
    final db = await instance();
    final batch = db.batch();
    final now = DateTime.now().toUtc().toIso8601String();
    for (final c in list) {
      batch.insert("courses", {
        "id": c.id,
        "title": c.title,
        "description": c.description,
        "difficulty": c.difficulty,
        "estimated_minutes": c.estimatedMinutes,
        "content_version": c.contentVersion,
        "progress_percent": c.progressPercent,
        "cached_at": now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> replaceLessonsForCourse(String courseId, List<LessonSummary> lessons) async {
    final db = await instance();
    await db.delete("lessons", where: "course_id = ?", whereArgs: [courseId]);
    final batch = db.batch();
    final now = DateTime.now().toUtc().toIso8601String();
    for (final l in lessons) {
      batch.insert("lessons", {
        "id": l.id,
        "course_id": courseId,
        "title": l.title,
        "order_index": l.orderIndex,
        "ui_status": l.status,
        "content_version": l.contentVersion,
        "blocks_json": null,
        "cached_at": now,
      });
    }
    await batch.commit(noResult: true);
  }

  /// Обновить только отображаемый статус (например после «выполнено» локально).
  static Future<void> updateLessonUiStatus(String lessonId, String uiStatus) async {
    final db = await instance();
    await db.update(
      "lessons",
      {"ui_status": uiStatus},
      where: "id = ?",
      whereArgs: [lessonId],
    );
  }

  static Future<void> upsertLessonDetail(LessonDetail lesson) async {
    final db = await instance();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert("lessons", {
      "id": lesson.id,
      "course_id": lesson.courseId,
      "title": lesson.title,
      "order_index": lesson.orderIndex,
      "ui_status": lesson.uiStatus,
      "content_version": lesson.contentVersion,
      "blocks_json": lesson.blocksJson,
      "cached_at": now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<LessonDetail?> getLessonCached(String lessonId) async {
    final db = await instance();
    final rows = await db.query("lessons", where: "id = ?", whereArgs: [lessonId], limit: 1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    final blocks = r["blocks_json"] as String?;
    if (blocks == null || blocks.isEmpty) return null;
    return LessonDetail(
      id: r["id"]! as String,
      courseId: r["course_id"]! as String,
      title: r["title"]! as String,
      orderIndex: r["order_index"]! as int,
      uiStatus: r["ui_status"]! as String,
      contentVersion: r["content_version"]! as int,
      blocksJson: blocks,
    );
  }

  static Future<List<LessonSummary>> getLessonsForCourse(String courseId) async {
    final db = await instance();
    final rows = await db.query(
      "lessons",
      where: "course_id = ?",
      whereArgs: [courseId],
      orderBy: "order_index ASC",
    );
    return rows
        .map(
          (r) => LessonSummary(
            id: r["id"]! as String,
            title: r["title"]! as String,
            orderIndex: r["order_index"]! as int,
            status: r["ui_status"]! as String,
            contentVersion: r["content_version"]! as int,
          ),
        )
        .toList();
  }

  static Future<void> enqueueProgress(String eventId, String payloadJson) async {
    final db = await instance();
    await db.insert("sync_queue", {
      "event_id": eventId,
      "payload": payloadJson,
      "created_at": DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> pendingProgress() async {
    final db = await instance();
    final rows = await db.query("sync_queue", orderBy: "created_at ASC");
    return rows;
  }

  static Future<int> pendingProgressCount() async {
    final db = await instance();
    final r = await db.rawQuery("SELECT COUNT(*) AS c FROM sync_queue");
    return Sqflite.firstIntValue(r) ?? 0;
  }

  static Future<void> markProgressSynced(List<String> eventIds) async {
    if (eventIds.isEmpty) return;
    final db = await instance();
    final batch = db.batch();
    for (final id in eventIds) {
      batch.delete("sync_queue", where: "event_id = ?", whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> startCourse({
    required String userKey,
    required String courseId,
  }) async {
    final db = await instance();
    await db.insert("started_courses", {
      "user_key": userKey,
      "course_id": courseId,
      "started_at": DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<bool> isCourseStarted({
    required String userKey,
    required String courseId,
  }) async {
    final db = await instance();
    final rows = await db.query(
      "started_courses",
      columns: ["course_id"],
      where: "user_key = ? AND course_id = ?",
      whereArgs: [userKey, courseId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  static Future<List<String>> getStartedCourseIds({required String userKey}) async {
    final db = await instance();
    final rows = await db.query(
      "started_courses",
      where: "user_key = ?",
      whereArgs: [userKey],
      orderBy: "started_at DESC",
    );
    return rows.map((r) => r["course_id"] as String).toList();
  }
}
