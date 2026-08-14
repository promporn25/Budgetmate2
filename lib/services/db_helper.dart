import 'package:cloud_firestore/cloud_firestore.dart';

/// ทุกเมธอดที่ยิง network ไป Firestore จะมี timeout กำกับไว้เสมอ (10 วิ)
/// เพื่อไม่ให้ UI ค้าง/หมุนไปเรื่อยๆ แบบไม่มีที่สิ้นสุดถ้าเน็ตช้าหรือ
/// หลุดกลางทาง — เดิมมีแต่ login/register ที่ตั้ง timeout ไว้ ส่วน
/// insert/update/delete/query (ที่ทุกหน้าจอเรียกใช้ตลอด) ไม่มี timeout เลย
const _dbTimeout = Duration(seconds: 10);

class DBHelper {
  DBHelper._internal();
  static final DBHelper instance = DBHelper._internal();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String table) =>
      _fs.collection(table);

  // ---------------- Generic CRUD helpers ----------------
  // ใช้ data['id'] เป็น document id เสมอ (โค้ดเดิมสร้าง id ด้วย uuid อยู่แล้ว)
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final id = data['id'] as String;
    await _col(table).doc(id).set(data).timeout(
          _dbTimeout,
          onTimeout: () => throw Exception('เชื่อมต่อฐานข้อมูลไม่ได้ (หมดเวลา) - เช็คอินเทอร์เน็ต'),
        );
    return 1;
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
      await batch.commit().timeout(
            _dbTimeout,
            onTimeout: () => throw Exception('บันทึกไม่สำเร็จ (หมดเวลาเชื่อมต่อ) - เช็คอินเทอร์เน็ต'),
          );
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

    final snap = await q.get().timeout(
          _dbTimeout,
          onTimeout: () => throw Exception('โหลดข้อมูลไม่สำเร็จ (หมดเวลาเชื่อมต่อ) - เช็คอินเทอร์เน็ต'),
        );
    return snap.docs.map((d) => d.data()).toList();
  }

  // รองรับเฉพาะ where = 'id = ?' (ตรงกับที่ใช้ทั้งโปรเจกต์)
  Future<int> update(
    String table,
    Map<String, dynamic> data,
    String where,
    List<Object?> whereArgs,
  ) async {
    final id = whereArgs.first.toString();
    await _col(table).doc(id).set(data, SetOptions(merge: true)).timeout(
          _dbTimeout,
          onTimeout: () => throw Exception('บันทึกไม่สำเร็จ (หมดเวลาเชื่อมต่อ) - เช็คอินเทอร์เน็ต'),
        );
    return 1;
  }

  Future<int> delete(String table, String where, List<Object?> whereArgs) async {
    final id = whereArgs.first.toString();
    await _col(table).doc(id).delete().timeout(
          _dbTimeout,
          onTimeout: () => throw Exception('ลบไม่สำเร็จ (หมดเวลาเชื่อมต่อ) - เช็คอินเทอร์เน็ต'),
        );
    return 1;
  }

  Future<int> count(String table) async {
    final agg = await _col(table).count().get().timeout(_dbTimeout);
    return agg.count ?? 0;
  }
}