import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


const _dbTimeout = Duration(seconds: 10);

class DBHelper {
  DBHelper._internal();
  static final DBHelper instance = DBHelper._internal();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String table) =>
      _fs.collection(table);

 
  Never _handleError(Object e, StackTrace st, String fallbackMessage) {
  
    debugPrint('[DBHelper] RAW ERROR TYPE=${e.runtimeType} VALUE=$e');
    if (e is TimeoutException) {
      debugPrint('[DBHelper] TIMEOUT after ${_dbTimeout.inSeconds}s: $fallbackMessage');
      throw Exception('$fallbackMessage (หมดเวลา) - เช็คอินเทอร์เน็ต');
    }
    if (e is FirebaseException) {
      debugPrint('[DBHelper] FirebaseException code=${e.code} message=${e.message}');
      switch (e.code) {
        case 'permission-denied':
          throw Exception('$fallbackMessage (ไม่มีสิทธิ์เข้าถึงข้อมูล - ตรวจสอบ Firestore Security Rules)');
        case 'unavailable':
          throw Exception('$fallbackMessage (เชื่อมต่อ Firestore ไม่ได้ - เช็คอินเทอร์เน็ต/สถานะ Firebase)');
        default:
          throw Exception('$fallbackMessage (${e.code}: ${e.message})');
      }
    }
    debugPrint('[DBHelper] Unexpected error: $e\n$st');
    throw Exception('$fallbackMessage ($e)');
  }

  // ---------------- Generic CRUD helpers ----------------
  // ใช้ data['id'] เป็น document id เสมอ (โค้ดเดิมสร้าง id ด้วย uuid อยู่แล้ว)
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final id = data['id'] as String;
    try {
      await _col(table).doc(id).set(data).timeout(_dbTimeout);
      return 1;
    } catch (e, st) {
      _handleError(e, st, 'บันทึกไม่สำเร็จ');
    }
  }

  // เพิ่มหลายรายการในครั้งเดียวด้วย WriteBatch (1 round-trip แทนที่จะยิงทีละรายการ)
  // Firestore batch รองรับสูงสุด 500 operations ต่อ batch จึงแบ่งเป็นชุดๆ ถ้าเผื่อไว้
  Future<void> insertBatch(String table, List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    const chunkSize = 450;
    for (int i = 0; i < items.length; i += chunkSize) {
      final chunk = items.sublist(i, i + chunkSize > items.length ? items.length : i + chunkSize);
      final batch = _fs.batch();
      for (final data in chunk) {
        final id = data['id'] as String;
        batch.set(_col(table).doc(id), data);
      }
      try {
        await batch.commit().timeout(_dbTimeout);
      } catch (e, st) {
        _handleError(e, st, 'บันทึกไม่สำเร็จ');
      }
    }
  }

  // รองรับเฉพาะ where แบบ 'field = ?' กับ whereArgs 1 ค่า (ตรงกับที่ใช้ทั้งโปรเจกต์)
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    Query<Map<String, dynamic>> q = _col(table);

    if (where != null && whereArgs != null && whereArgs.isNotEmpty) {
      final field = where.split('=').first.trim();
      q = q.where(field, isEqualTo: whereArgs.first);
    }

    if (orderBy != null && orderBy.trim().isNotEmpty) {
      final parts = orderBy.trim().split(RegExp(r'\s+'));
      final field = parts[0];
      final desc = parts.length > 1 && parts[1].toUpperCase() == 'DESC';
      q = q.orderBy(field, descending: desc);
    }

    try {
      final snap = await q.get().timeout(_dbTimeout);
      return snap.docs.map((d) => d.data()).toList();
    } catch (e, st) {
      _handleError(e, st, 'โหลดข้อมูลไม่สำเร็จ');
    }
  }

  // รองรับเฉพาะ where = 'id = ?' (ตรงกับที่ใช้ทั้งโปรเจกต์)
  Future<int> update(
    String table,
    Map<String, dynamic> data,
    String where,
    List<Object?> whereArgs,
  ) async {
    final id = whereArgs.first.toString();
    try {
      await _col(table).doc(id).set(data, SetOptions(merge: true)).timeout(_dbTimeout);
      return 1;
    } catch (e, st) {
      _handleError(e, st, 'บันทึกไม่สำเร็จ');
    }
  }

  Future<int> delete(String table, String where, List<Object?> whereArgs) async {
    final id = whereArgs.first.toString();
    try {
      await _col(table).doc(id).delete().timeout(_dbTimeout);
      return 1;
    } catch (e, st) {
      _handleError(e, st, 'ลบไม่สำเร็จ');
    }
  }

  Future<int> count(String table) async {
    try {
      final agg = await _col(table).count().get().timeout(_dbTimeout);
      return agg.count ?? 0;
    } catch (e, st) {
      _handleError(e, st, 'นับจำนวนรายการไม่สำเร็จ');
    }
  }
}