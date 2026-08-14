/// เอนทิตี้ User ตามพจนานุกรมข้อมูลในเอกสารบทที่ 3
/// หมายเหตุ: ไม่เก็บรหัสผ่านไว้ที่นี่/ใน Firestore อีกต่อไป เพราะการยืนยันตัวตน
/// (ล็อกอิน/สมัครสมาชิก/ลืมรหัสผ่าน) ถูกโอนไปให้ Firebase Authentication ดูแลทั้งหมด
/// id ของโมเดลนี้ = uid ที่ Firebase Authentication สร้างให้ผู้ใช้แต่ละคน
class UserModel {
  final String id; // user_id (= Firebase Auth uid)
  String name; // name
  String email; // email
  final DateTime createdAt; // created_at
  String language; // ตั้งค่าในหน้า Information / Account Setting
  String currency;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
    this.language = 'ไทย',
    this.currency = 'THB',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'created_at': createdAt.toIso8601String(),
      'language': language,
      'currency': currency,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      language: map['language'] as String? ?? 'ไทย',
      currency: map['currency'] as String? ?? 'THB',
    );
  }
}