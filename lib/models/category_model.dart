import 'package:flutter/material.dart';

/// ประเภทของหมวดหมู่ สอดคล้องกับ Entity Category (category_type)
enum CategoryType { income, expense }

/// เอนทิตี้ Category ตามพจนานุกรมข้อมูลในเอกสารบทที่ 3
class CategoryModel {
  final String id; // category_id
  final String name; // category_name
  final CategoryType type; // category_type
  final IconData
      icon; // ไอคอน fallback เสมอ (ใช้ตอนยังไม่มีรูป หรือโหลดรูปไม่สำเร็จ)
  final String? description; // description

  /// path ไฟล์รูปภาพไอคอนหมวดหมู่ (เช่น 'assets/images/categories/c01.png')
  /// ถ้าเป็น null หรือโหลดไฟล์ไม่สำเร็จ (เช่น ยังไม่ได้ใส่ไฟล์จริงลง assets)
  /// ตัว CategoryIcon widget จะ fallback กลับไปแสดง [icon] แทนโดยอัตโนมัติ
  final String? imagePath;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    this.description,
    this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type == CategoryType.income ? 'income' : 'expense',
      'icon_code': icon.codePoint,
      'description': description,
      'image_path': imagePath,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      type:
          map['type'] == 'income' ? CategoryType.income : CategoryType.expense,
      // หมายเหตุ: ไอคอนมาตรฐานของ Icons.* ใช้ fontFamily 'MaterialIcons'
      icon: IconData(map['icon_code'] as int, fontFamily: 'MaterialIcons'),
      description: map['description'] as String?,
      imagePath: map['image_path'] as String?,
    );
  }
}

/// วิดเจ็ตแสดงไอคอนของหมวดหมู่ — ใช้แทน `Icon(category.icon, ...)` ได้ทุกจุดในแอป
/// ถ้า [CategoryModel.imagePath] ตั้งไว้และโหลดรูปสำเร็จ จะแสดงรูปภาพนั้นแทน
/// ถ้าไม่ได้ตั้งไว้ (null) หรือโหลดรูปไม่สำเร็จ (เช่น ยังไม่มีไฟล์จริงใน assets)
/// จะ fallback กลับไปแสดง Material Icon (category.icon) โดยอัตโนมัติ ไม่ทำให้แอปพัง
///
/// หมายเหตุเรื่องสี: [color] จะถูกใช้ "ทาสีทับ" เฉพาะตอน fallback เป็น Material Icon
/// เท่านั้น (เช่น ตอนที่ยังไม่มีไฟล์รูปจริง) ส่วนตอนแสดงรูปภาพจริงจะ "ไม่" ทาสีทับ
/// เพราะรูปภาพหมวดหมู่มักเป็นภาพสีเต็ม/หลายสี ถ้า tint สีทับ (เช่นตอนเลือกแล้วเปลี่ยน
/// เป็นสีขาว) จะทำให้รูปเพี้ยนหรือมองไม่เห็นรายละเอียด จึงปล่อยให้รูปแสดงสีตามต้นฉบับ
/// แล้วใช้สีพื้นหลัง/ขอบวงกลมรอบๆ แทนในการสื่อสถานะ selected/unselected
class CategoryIcon extends StatelessWidget {
  final CategoryModel category;
  final double size;
  final Color? color;

  const CategoryIcon(
      {super.key, required this.category, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    final path = category.imagePath;
    if (path == null || path.isEmpty) {
      return Icon(category.icon, size: size, color: color);
    }
    return Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          Icon(category.icon, size: size, color: color),
    );
  }
}

/// หมวดหมู่เริ่มต้นของระบบ (จะถูก seed ลง SQLite อัตโนมัติครั้งแรกที่เปิดแอป)
/// imagePath เตรียม path ไว้ล่วงหน้าตาม id (เช่น c01 -> c01.png) พอมีไฟล์รูปจริง
/// แค่นำไปวางที่ assets/images/categories/ ตามชื่อไฟล์นี้ได้เลย ไม่ต้องแก้โค้ดเพิ่ม
/// (ถ้ายังไม่มีไฟล์ตอนนี้ก็ไม่เป็นไร CategoryIcon จะ fallback ไปใช้ icon เดิมให้อัตโนมัติ)
const String _catImgBase = 'assets/images/categories';
final List<CategoryModel> defaultCategories = [
  CategoryModel(
      id: 'c01',
      name: 'อาหาร',
      type: CategoryType.expense,
      icon: Icons.restaurant,
      imagePath: '$_catImgBase/c01.png'),
  CategoryModel(
      id: 'c02',
      name: 'เครื่องดื่ม',
      type: CategoryType.expense,
      icon: Icons.local_cafe,
      imagePath: '$_catImgBase/c02.png'),
  CategoryModel(
      id: 'c03',
      name: 'ที่พัก',
      type: CategoryType.expense,
      icon: Icons.home,
      imagePath: '$_catImgBase/c03.png'),
  CategoryModel(
      id: 'c04',
      name: 'ยานพาหนะ',
      type: CategoryType.expense,
      icon: Icons.directions_car,
      imagePath: '$_catImgBase/c04.png'),
  CategoryModel(
      id: 'c05',
      name: 'ภาษี',
      type: CategoryType.expense,
      icon: Icons.receipt_long,
      imagePath: '$_catImgBase/c05.png'),
  CategoryModel(
      id: 'c06',
      name: 'ช้อปปิ้ง',
      type: CategoryType.expense,
      icon: Icons.shopping_bag,
      imagePath: '$_catImgBase/c06.png'),
  CategoryModel(
      id: 'c07',
      name: 'ของขวัญ',
      type: CategoryType.expense,
      icon: Icons.card_giftcard,
      imagePath: '$_catImgBase/c07.png'),
  CategoryModel(
      id: 'c08',
      name: 'ท่องเที่ยว',
      type: CategoryType.expense,
      icon: Icons.flight,
      imagePath: '$_catImgBase/c08.png'),
  CategoryModel(
      id: 'c09',
      name: 'ความงาม',
      type: CategoryType.expense,
      icon: Icons.spa,
      imagePath: '$_catImgBase/c09.png'),
  CategoryModel(
      id: 'c10',
      name: 'บันเทิง',
      type: CategoryType.expense,
      icon: Icons.music_note,
      imagePath: '$_catImgBase/c10.png'),
  CategoryModel(
      id: 'c11',
      name: 'กีฬา',
      type: CategoryType.expense,
      icon: Icons.sports_soccer,
      imagePath: '$_catImgBase/c11.png'),
  CategoryModel(
      id: 'c12',
      name: 'สัตว์เลี้ยง',
      type: CategoryType.expense,
      icon: Icons.pets,
      imagePath: '$_catImgBase/c12.png'),
  CategoryModel(
      id: 'c13',
      name: 'การศึกษา',
      type: CategoryType.expense,
      icon: Icons.school,
      imagePath: '$_catImgBase/c13.png'),
  CategoryModel(
      id: 'c14',
      name: 'เงินเดือน',
      type: CategoryType.income,
      icon: Icons.payments,
      imagePath: '$_catImgBase/c14.png'),
  CategoryModel(
      id: 'c15',
      name: 'รายได้เสริม',
      type: CategoryType.income,
      icon: Icons.trending_up,
      imagePath: '$_catImgBase/c15.png'),
  CategoryModel(
      id: 'c16',
      name: 'โบนัส',
      type: CategoryType.income,
      icon: Icons.card_membership,
      imagePath: '$_catImgBase/c16.png'),
  // หมวดหมู่รายจ่ายพิเศษ: ใช้บันทึกอัตโนมัติเมื่อผู้ใช้ "โอนเงินจริง" เข้าเป้าหมายการออม
  // (ต้องใช้ id คงที่ 'c17' เพื่อให้ DataService ค้นหา/สร้างซ้ำได้อย่างสม่ำเสมอ)
  CategoryModel(
      id: 'c17',
      name: 'เงินออม',
      type: CategoryType.expense,
      icon: Icons.savings,
      imagePath: '$_catImgBase/c17.png'),
];
