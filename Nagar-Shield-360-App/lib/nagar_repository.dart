import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'app_config.dart';
import 'demo_flow.dart';
import 'staff_outbox.dart';

typedef RowData = Map<String, dynamic>;

class NagarRepository {
  NagarRepository(this.client, this.database)
    : staffOutbox = StaffOutbox(client, database);

  final SupabaseClient? client;
  final Database database;
  final StaffOutbox staffOutbox;
  static const _uuid = Uuid();
  static const _secure = FlutterSecureStorage();
  static const _publicSessionKey = 'nagar_public_refresh_token';
  static const _publicDemoSlotKey = 'nagar_public_demo_slot';

  static Future<NagarRepository> open(SupabaseClient? client) async {
    final root = await getApplicationDocumentsDirectory();
    final database = await openDatabase(
      '${root.path}/nagarshield.db',
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE report_outbox (
            request_id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            categories TEXT NOT NULL,
            area TEXT NOT NULL,
            lat REAL NOT NULL,
            lng REAL NOT NULL,
            precision TEXT NOT NULL,
            media_path TEXT,
            remote_id TEXT,
            status TEXT NOT NULL,
            error TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE demo_state (
            id INTEGER PRIMARY KEY CHECK (id=1),
            incident_status TEXT NOT NULL,
            task_status TEXT NOT NULL,
            event_log TEXT NOT NULL
          )
        ''');
        await StaffOutbox.migrate(db);
        await db.execute(
          'CREATE TABLE official_profile_cache (uid TEXT PRIMARY KEY, profile TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE public_draft (id INTEGER PRIMARY KEY CHECK (id=1), payload TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE studio_imports (id TEXT PRIMARY KEY, media_path TEXT NOT NULL, annotations TEXT NOT NULL, created_at TEXT NOT NULL)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await StaffOutbox.migrate(db);
        if (oldVersion < 3) {
          await db.execute(
            'CREATE TABLE official_profile_cache (uid TEXT PRIMARY KEY, profile TEXT NOT NULL)',
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            'CREATE TABLE public_draft (id INTEGER PRIMARY KEY CHECK (id=1), payload TEXT NOT NULL)',
          );
        }
        if (oldVersion < 5) {
          await db.execute(
            'CREATE TABLE studio_imports (id TEXT PRIMARY KEY, media_path TEXT NOT NULL, annotations TEXT NOT NULL, created_at TEXT NOT NULL)',
          );
        }
      },
    );
    return NagarRepository(client, database);
  }

  bool get configured => client != null;
  User? get user => client?.auth.currentUser;

  Future<RowData?> officialProfile() async {
    final current = user;
    if (client == null || current == null) return null;
    try {
      final result = await client!
          .from('profiles')
          .select('id,display_name,role,department_id,team_id')
          .eq('id', current.id)
          .maybeSingle();
      if (result != null) {
        await database.insert('official_profile_cache', {
          'uid': current.id,
          'profile': jsonEncode(result),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      return result;
    } catch (_) {
      final cached = await database.query(
        'official_profile_cache',
        where: 'uid=?',
        whereArgs: [current.id],
      );
      return cached.isEmpty
          ? null
          : (jsonDecode(cached.single['profile'] as String) as Map)
                .cast<String, dynamic>();
    }
  }

  Future<void> signIn(String email, String password) async {
    if (client == null) throw StateError('Supabase is not configured.');
    if (user != null && await officialProfile() == null) {
      final refreshToken = client!.auth.currentSession?.refreshToken;
      if (refreshToken != null) {
        await _secure.write(key: _publicSessionKey, value: refreshToken);
      }
    }
    await client!.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (await officialProfile() == null) {
      await client!.auth.signOut();
      throw StateError('This account has no official role.');
    }
  }

  Future<void> signOut() async => client?.auth.signOut();

  Future<String?> selectedPublicDemoSlot() async {
    if (!AppConfig.hasMultiplePublicDemoIdentities) {
      return AppConfig.publicDemoSlot.isEmpty ? null : AppConfig.publicDemoSlot;
    }
    return _secure.read(key: _publicDemoSlotKey);
  }

  Future<void> selectPublicDemoSlot(String slot) async {
    if (AppConfig.publicDemoAccount(slot) == null) {
      throw StateError('Unknown public demo identity.');
    }
    final previous = await selectedPublicDemoSlot();
    if (previous != null && previous != slot) {
      throw StateError(
        'This installation already uses public identity $previous.',
      );
    }
    if (user != null && await officialProfile() == null) {
      await client?.auth.signOut();
      await _secure.delete(key: _publicSessionKey);
    }
    await _secure.write(key: _publicDemoSlotKey, value: slot);
  }

  Future<void> ensurePublicSession() async {
    if (client == null) throw StateError('Supabase is not configured.');
    if (user != null) {
      if (await officialProfile() != null) {
        throw StateError('Sign out of the official account first.');
      }
      final refreshToken = client!.auth.currentSession?.refreshToken;
      if (refreshToken != null) {
        await _secure.write(key: _publicSessionKey, value: refreshToken);
      }
      return;
    }
    final saved = await _secure.read(key: _publicSessionKey);
    if (saved != null) {
      try {
        await client!.auth.setSession(saved);
        final renewed = client!.auth.currentSession?.refreshToken;
        if (renewed != null) {
          await _secure.write(key: _publicSessionKey, value: renewed);
        }
        return;
      } catch (_) {
        await _secure.delete(key: _publicSessionKey);
      }
    }
    if (AppConfig.hasPublicDemoIdentity) {
      final slot = await selectedPublicDemoSlot();
      final account = AppConfig.publicDemoAccount(slot);
      if (account == null) {
        throw StateError('Choose a public demo identity on this phone first.');
      }
      await client!.auth.signInWithPassword(
        email: account['email'].toString(),
        password: account['password'].toString(),
      );
    } else {
      await client!.auth.signInAnonymously();
    }
    final refreshToken = client!.auth.currentSession?.refreshToken;
    if (refreshToken != null) {
      await _secure.write(key: _publicSessionKey, value: refreshToken);
    }
  }

  Future<String> queuePublicReport({
    required String title,
    required String description,
    required List<String> categories,
    required String area,
    required double lat,
    required double lng,
    required String precision,
    String? imagePath,
  }) async {
    if (title.trim().length < 4 || categories.isEmpty || area.trim().isEmpty) {
      throw ArgumentError('Add a title, category and location.');
    }
    if (imagePath == null && description.trim().length < 12) {
      throw ArgumentError('Add a photo or explain the problem.');
    }
    final id = _uuid.v4();
    String? savedPath;
    if (imagePath != null) {
      final root = await getApplicationDocumentsDirectory();
      final dir = Directory('${root.path}/report_media');
      await dir.create(recursive: true);
      final extension = imagePath.toLowerCase().endsWith('.png')
          ? 'png'
          : 'jpg';
      savedPath = '${dir.path}/$id.$extension';
      await File(imagePath).copy(savedPath);
    }
    await database.insert('report_outbox', {
      'request_id': id,
      'title': title.trim(),
      'description': description.trim(),
      'categories': jsonEncode(categories),
      'area': area.trim(),
      'lat': lat,
      'lng': lng,
      'precision': precision,
      'media_path': savedPath,
      'status': 'queued',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    return id;
  }

  Future<List<RowData>> localReports() async =>
      database.query('report_outbox', orderBy: 'created_at DESC');

  Future<RowData?> publicDraft() async {
    final rows = await database.query('public_draft', where: 'id=1');
    return rows.isEmpty
        ? null
        : (jsonDecode(rows.single['payload'] as String) as Map)
              .cast<String, dynamic>();
  }

  Future<void> savePublicDraft(RowData draft) async {
    await database.insert('public_draft', {
      'id': 1,
      'payload': jsonEncode(draft),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearPublicDraft() =>
      database.delete('public_draft', where: 'id=1');

  Future<List<RowData>> studioImports() async =>
      database.query('studio_imports', orderBy: 'created_at DESC');

  Future<RowData> importStudioMedia(String originalPath) async {
    final id = _uuid.v4();
    final extension = originalPath.split('.').last.toLowerCase();
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory('${root.path}/studio_media');
    await folder.create(recursive: true);
    final saved = await File(
      originalPath,
    ).copy('${folder.path}/$id.$extension');
    final row = <String, dynamic>{
      'id': id,
      'media_path': saved.path,
      'annotations': '[]',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    await database.insert('studio_imports', row);
    return row;
  }

  Future<void> saveStudioAnnotations(String id, List<RowData> annotations) =>
      database.update(
        'studio_imports',
        {'annotations': jsonEncode(annotations)},
        where: 'id=?',
        whereArgs: [id],
      );

  Future<void> deleteStudioImport(String id) async {
    final rows = await database.query(
      'studio_imports',
      where: 'id=?',
      whereArgs: [id],
    );
    if (rows.isNotEmpty) {
      final file = File(rows.single['media_path'] as String);
      if (await file.exists()) await file.delete();
    }
    await database.delete('studio_imports', where: 'id=?', whereArgs: [id]);
  }

  Future<void> flushReports() async {
    if (client == null) return;
    final queued = await database.query(
      'report_outbox',
      where: "status IN ('queued','failed')",
      orderBy: 'created_at ASC',
    );
    if (queued.isEmpty) return;
    try {
      await ensurePublicSession();
    } catch (error) {
      for (final row in queued) {
        await database.update(
          'report_outbox',
          {'status': 'failed', 'error': error.toString()},
          where: 'request_id=?',
          whereArgs: [row['request_id']],
        );
      }
      return;
    }
    for (final row in queued) {
      final id = row['request_id'] as String;
      try {
        String? key;
        String? mime;
        final mediaPath = row['media_path'] as String?;
        if (mediaPath != null) {
          final png = mediaPath.toLowerCase().endsWith('.png');
          mime = png ? 'image/png' : 'image/jpeg';
          key = 'public/${user!.id}/$id.${png ? 'png' : 'jpg'}';
          await client!.storage
              .from('evidence')
              .upload(
                key,
                File(mediaPath),
                fileOptions: FileOptions(contentType: mime, upsert: true),
              );
        }
        final remoteId = await client!.rpc(
          'submit_public_report',
          params: {
            'p_request_id': id,
            'p_title': row['title'],
            'p_description': row['description'],
            'p_categories': jsonDecode(row['categories'] as String),
            'p_area': row['area'],
            'p_lat': row['lat'],
            'p_lng': row['lng'],
            'p_precision': row['precision'],
            'p_media_key': key,
            'p_mime_type': mime,
          },
        );
        await database.update(
          'report_outbox',
          {
            'remote_id': remoteId.toString(),
            'status': 'submitted',
            'error': null,
          },
          where: 'request_id=?',
          whereArgs: [id],
        );
      } catch (error) {
        await database.update(
          'report_outbox',
          {'status': 'failed', 'error': error.toString()},
          where: 'request_id=?',
          whereArgs: [id],
        );
      }
    }
  }

  Future<List<RowData>> publicReportStatuses() async {
    if (client == null || (user != null && await officialProfile() != null)) {
      return [];
    }
    try {
      await ensurePublicSession();
      final result = await client!.rpc('public_report_status');
      return (result as List).cast<RowData>();
    } catch (_) {
      return [];
    }
  }

  Future<List<RowData>> incidents() async {
    if (client == null) return [];
    final rows = await client!
        .from('incidents')
        .select(
          'id,code,title_bn,description_bn,status,priority,score,area_bn,lat,lng,'
          'department_id,escalated,before_key,after_key,updated_at',
        )
        .order('updated_at', ascending: false);
    return rows.cast<RowData>();
  }

  Future<List<RowData>> tasks() async {
    if (client == null) return [];
    final rows = await client!
        .from('tasks')
        .select(
          'id,incident_id,department_id,team_id,assignee_id,status,note,'
          'completion_note,created_at,incidents(code,title_bn,area_bn,status)',
        )
        .order('created_at', ascending: false);
    return rows.cast<RowData>();
  }

  Future<List<RowData>> notifications() async {
    if (client == null || client!.auth.currentUser == null) return [];
    try {
      final rows = await client!
          .from('notifications')
          .select('id,incident_id,text_bn,created_at')
          .eq('recipient_id', client!.auth.currentUser!.id)
          .order('created_at', ascending: false)
          .limit(5);
      return rows.cast<RowData>();
    } catch (_) {
      return [];
    }
  }

  Future<List<RowData>> staffDirectory() async {
    if (client == null) return [];
    final rows = await client!
        .from('profiles')
        .select('id,display_name,role,department_id,team_id')
        .order('display_name');
    return rows.cast<RowData>();
  }

  Future<List<RowData>> reviewQueue() async {
    if (client == null) return [];
    final rows = await client!
        .from('observations')
        .select(
          'id,title_bn,description_bn,status,source,report_code,area_bn,'
          'department_id,media_key,created_at',
        )
        .eq('status', 'needs_review')
        .order('created_at', ascending: false);
    return rows.cast<RowData>();
  }

  Future<List<RowData>> scenarios() async {
    if (client == null) return [];
    final rows = await client!
        .from('scenarios')
        .select(
          'id,title_bn,summary_bn,kind,hazard,area_bn,media_key,detections,factors',
        )
        .order('id');
    return rows.cast<RowData>();
  }

  Future<List<RowData>> events(String incidentId) async {
    if (client == null) return [];
    final rows = await client!
        .from('events')
        .select('id,actor_id,kind,note,created_at')
        .eq('incident_id', incidentId)
        .order('created_at', ascending: false);
    return rows.cast<RowData>();
  }

  Future<bool> workflow(
    String action, {
    String? target,
    RowData payload = const {},
  }) => staffOutbox.queueAction(action, target: target, payload: payload);

  Future<bool> reviewIntake(String id, bool approve, {String note = ''}) =>
      staffOutbox.queueAction(
        approve ? 'verify_intake' : 'dismiss_intake',
        target: id,
        payload: {'note': note},
      );

  Future<void> flushStaffActions() => staffOutbox.flush();

  Future<List<RowData>> pendingStaffActions() => staffOutbox.pending();

  Future<void> discardStaffAction(String kind, String id) =>
      staffOutbox.discard(kind, id);

  Future<void> retryStaffAction(String kind, String id) =>
      staffOutbox.retry(kind, id);

  Future<String> signedMediaUrl(String key) async {
    if (client == null) throw StateError('Supabase is not configured.');
    final bucket = key.startsWith('scenarios/') ? 'demo-media' : 'evidence';
    return client!.storage.from(bucket).createSignedUrl(key, 600);
  }

  Future<bool> submitTaskEvidence({
    required String taskId,
    required String note,
    required String imagePath,
  }) => staffOutbox.queueEvidence(
    taskId: taskId,
    note: note,
    imagePath: imagePath,
  );

  Future<RowData> demoState() async {
    final rows = await database.query('demo_state', where: 'id=1');
    if (rows.isNotEmpty) return rows.first;
    await resetDemo();
    return (await database.query('demo_state', where: 'id=1')).first;
  }

  Future<void> resetDemo() async {
    const state = DemoState.initial;
    await database.insert('demo_state', {
      'id': 1,
      'incident_status': state.incidentStatus,
      'task_status': state.taskStatus,
      'event_log': jsonEncode(state.events),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> advanceDemo(String action) async {
    final state = await demoState();
    final next = DemoFlow.advance(
      DemoState(
        incidentStatus: state['incident_status'] as String,
        taskStatus: state['task_status'] as String,
        events: (jsonDecode(state['event_log'] as String) as List)
            .cast<String>(),
      ),
      action,
    );
    await database.update('demo_state', {
      'incident_status': next.incidentStatus,
      'task_status': next.taskStatus,
      'event_log': jsonEncode(next.events),
    }, where: 'id=1');
  }
}
