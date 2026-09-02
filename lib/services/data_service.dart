import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'db_helper.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/goal_model.dart';
import '../models/user_model.dart';
import 'app_strings.dart';
import '../screens/app_theme.dart'; // เพิ่มบรรทัดนี้
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

const _setupDoneKey = 'budgetmate_setup_completed';
const _defaultLangKey = 'budgetmate_default_language';
const _defaultCurrencyKey = 'budgetmate_default_currency';
const _themeModeKey = 'budgetmate_theme_mode'; // 'light' | 'dark'
const _successNotesKey = 'budgetmate_success_notes_enabled';

/// DataService รวบรวมการทำงานของระบบทั้งหมดตามขอบเขตโครงงาน (1.3.1 - 1.3.4)
/// เวอร์ชันนี้เก็บข้อมูลจริงลง SQLite ผ่าน DBHelper (ไม่ใช่ in-memory demo แล้ว)
/// - รายการ/เป้าหมายจะถูกโหลดเฉพาะของผู้ใช้ที่ล็อกอินอยู่ (currentUser)
/// - การยืนยันตัวตนทั้งหมด (สมัครสมาชิก/ล็อกอินด้วยอีเมล/ล็อกอินด้วย Google/ลืมรหัสผ่าน/
///   เปลี่ยนรหัสผ่าน) เชื่อมต่อกับ Firebase Authentication โดยตรง ไม่มีการเก็บรหัสผ่าน
///   หรือทำ hash เองในแอปอีกต่อไป ส่วนข้อมูลโปรไฟล์ (ชื่อ/ภาษา/สกุลเงิน ฯลฯ) เก็บใน
///   Firestore โดยใช้ uid จาก Firebase Auth เป็น document id
/// - สถานะล็อกอินถูกจำไว้โดย Firebase Authentication เองโดยอัตโนมัติ จึงไม่ต้อง
///   ล็อกอินใหม่ทุกครั้งที่เปิดแอป
class DataService extends ChangeNotifier {
  // ⚠️ DEBUG/ทดสอบ UI ชั่วคราว: ตั้งเป็น true เพื่อ "ข้าม" การเขียนข้อมูลลง Firestore
  // ทุกครั้ง ให้ทำงานกับ local state ในแอปอย่างเดียวแทน (กดบันทึกแล้วเห็นหน้าถัดไปทันที
  // ไม่ต้องรอ/พึ่งการเชื่อมต่อฐานข้อมูลจริง) — เมื่อแก้ปัญหาเชื่อมต่อ Firestore
  // (Security Rules / เครือข่าย) เสร็จแล้ว ให้เปลี่ยนกลับเป็น false เพื่อบันทึกข้อมูลจริง
  static const bool offlineMode = true;

  final _uuid = const Uuid();
  final _db = DBHelper.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ---------------- User session ----------------
  UserModel? currentUser;
  bool isReady = false;

  // ---------------- Profile picture (เก็บ path ไฟล์ในเครื่องผ่าน SharedPreferences ต่อผู้ใช้) ----------------
  String? avatarPath;

  // ---------------- ธีมของแอป (Light/Dark) ----------------
  ThemeMode themeMode = ThemeMode.light;

  // ---------------- ภาษาปัจจุบันของแอป ----------------
  // ใช้ currentUser?.language ถ้าล็อกอินอยู่ ไม่งั้น fallback ไปที่ค่า default
  // ที่ตั้งไว้ตอน setup (หน้า My wallet) เพื่อให้หน้าก่อนล็อกอิน (Login/Register/
  // Language Setup) เปลี่ยนภาษาได้เช่นกัน
  String _defaultLanguage = 'ไทย';
  String get currentLanguage => currentUser?.language ?? _defaultLanguage;

  /// แปลข้อความตาม key จาก AppStrings ตามภาษาปัจจุบันของแอป
  /// เรียกใช้ผ่าน context.watch<DataService>().t('key') ในทุกหน้า
  /// เพื่อให้ UI รีเฟรชเป็นภาษาใหม่ทันทีเมื่อ notifyListeners() ถูกเรียก
  String t(String key) => AppStrings.of(currentLanguage)[key] ?? key;

  /// แปลชื่อหมวดหมู่ตามภาษาปัจจุบัน สำหรับหมวดหมู่เริ่มต้นของระบบ (c01-c17)
  /// ซึ่งชื่อถูก seed ไว้เป็นภาษาไทยตายตัวใน SQLite ตั้งแต่แรก (ไม่ได้ผูกกับภาษา UI)
  /// จึงต้องแปลผ่าน key 'cat_<id>' แทนการอ่านชื่อจากฐานข้อมูลตรงๆ
  /// หมวดหมู่ที่ผู้ใช้สร้างเองเพิ่มเติม (id ไม่ตรงกับ c01-c17) จะใช้ชื่อเดิมตามที่ผู้ใช้ตั้งไว้
  String categoryName(CategoryModel category) {
    final strings = AppStrings.of(currentLanguage);
    return strings['cat_${category.id}'] ?? category.name;
  }

  /// เปลี่ยนภาษาทั้งแอปทันที ใช้ได้ทั้งก่อนและหลังล็อกอิน
  /// - ถ้าล็อกอินอยู่: บันทึกลงโปรไฟล์ผู้ใช้ใน SQLite ผ่าน updateProfile
  /// - ถ้ายังไม่ล็อกอิน: บันทึกเป็นค่า default ใน SharedPreferences
  Future<void> setLanguage(String language) async {
    if (currentUser != null) {
      await updateProfile(language: language);
    } else {
      _defaultLanguage = language;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_defaultLangKey, language);
      notifyListeners();
    }
  }

  // ---------------- การแจ้งเตือนเมื่อทำรายการสำเร็จ (Success Notes) ----------------
  bool successNotesEnabled = true;

  // ---------------- Category (โหลดทั้งหมดครั้งเดียวตอนเริ่มแอป) ----------------
  final List<CategoryModel> categories = [];

  // ---------------- Transaction (เฉพาะของผู้ใช้ที่ล็อกอินอยู่) ----------------
  final List<TransactionModel> _transactions = [];
  List<TransactionModel> get transactions => List.unmodifiable(_transactions.reversed);

  // ---------------- Goal Saving (เฉพาะของผู้ใช้ที่ล็อกอินอยู่) ----------------
  final List<GoalModel> _goals = [];
  List<GoalModel> get goals => List.unmodifiable(_goals);

  // =========================================================
  // เริ่มต้นระบบ: seed หมวดหมู่เริ่มต้น + กู้คืน session ที่ล็อกอินค้างไว้
  // เรียกครั้งเดียวจาก LoadingScreen ก่อนเข้าแอป
  // =========================================================
  Future<void> init() async {
    // TODO: ยังไม่เชื่อม SQLite สำหรับหมวดหมู่ตอนนี้ - ใช้ defaultCategories ตรงๆ ในหน่วยความจำไปก่อน
    // เมื่อพร้อมเชื่อม DB จริง ให้เปลี่ยนกลับไปเรียก _seedCategoriesIfEmpty() + _loadCategories() แทน
    categories
      ..clear()
      ..addAll(defaultCategories);

    final prefs = await SharedPreferences.getInstance();
    themeMode = (prefs.getString(_themeModeKey) ?? 'light') == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    successNotesEnabled = prefs.getBool(_successNotesKey) ?? true;
    _defaultLanguage = prefs.getString(_defaultLangKey) ?? 'ไทย';

    // Firebase Authentication จำสถานะล็อกอินไว้ให้เองอยู่แล้ว (persistent session)
    // จึงเช็คแค่ว่ามีผู้ใช้ที่ล็อกอินค้างอยู่หรือไม่ แล้วโหลดโปรไฟล์ที่ตรงกันจาก Firestore
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser != null) {
      try {
        final rows = await _db.query('users', where: 'id = ?', whereArgs: [fbUser.uid]);
        if (rows.isNotEmpty) {
          currentUser = UserModel.fromMap(rows.first);
          avatarPath = prefs.getString('avatar_path_${currentUser!.id}');
          await _loadUserData();
        }
      } catch (e) {
        // เชื่อมต่อ Firestore ไม่ได้ตอนเปิดแอป (เน็ตช้า/หลุด) - ปล่อยให้เข้าหน้า Login
        // ตามปกติแทนที่จะค้างที่ Loading ตลอดไป ผู้ใช้ล็อกอินใหม่ได้เองเมื่อเน็ตกลับมา
        currentUser = null;
      }
    }
    isReady = true;
    notifyListeners();
  }

  /// เพิ่มหมวดหมู่เริ่มต้นที่ยังไม่มีในฐานข้อมูล (เทียบทีละรายการด้วย id)
  /// ต่างจากเดิมที่เช็คแค่ "ตารางว่างหรือไม่" ครั้งเดียว ซึ่งทำให้เครื่องที่เคย
  /// ติดตั้งแอปไปแล้ว (มีหมวดหมู่เก่าอยู่บ้าง) ไม่เคยได้รับหมวดหมู่ใหม่ที่เพิ่มเข้ามาทีหลังเลย
  Future<void> _seedCategoriesIfEmpty() async {
    final rows = await _db.query('categories');
    final existingIds = rows.map((r) => r['id'] as String).toSet();
    for (final c in defaultCategories) {
      if (!existingIds.contains(c.id)) {
        await _db.insert('categories', c.toMap());
      }
    }
  }

  Future<void> _loadCategories() async {
    final rows = await _db.query('categories');
    categories
      ..clear()
      ..addAll(rows.map((r) => CategoryModel.fromMap(r)));
  }

  CategoryModel _categoryById(String id) {
    return categories.firstWhere(
      (c) => c.id == id,
      orElse: () => categories.isNotEmpty ? categories.first : defaultCategories.first,
    );
  }

  Future<void> _loadUserData() async {
    if (currentUser == null) return;
    final txRows = await _db.query(
      'transactions',
      where: 'user_id = ?',
      whereArgs: [currentUser!.id],
      orderBy: 'date ASC',
    );
    _transactions
      ..clear()
      ..addAll(txRows.map(
          (r) => TransactionModel.fromMap(r, _categoryById(r['category_id'] as String))));

    final goalRows = await _db.query(
      'goals',
      where: 'user_id = ?',
      whereArgs: [currentUser!.id],
    );
    _goals
      ..clear()
      ..addAll(goalRows.map((r) => GoalModel.fromMap(r)));
  }

  // =========================================================
  // SETUP (หน้า "My wallet" - เลือกภาษา/สกุลเงินเริ่มต้น แสดงครั้งแรกที่เปิดแอป)
  // =========================================================
  Future<bool> isSetupCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_setupDoneKey) ?? false;
  }

  /// บันทึกภาษา/สกุลเงินที่เลือกในหน้า My wallet ให้เป็นค่าเริ่มต้น
  /// (จะถูกนำไปใช้เป็นค่าตั้งต้นตอนสมัครสมาชิกครั้งแรก)
  Future<void> completeSetup({required String language, required String currency}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupDoneKey, true);
    await prefs.setString(_defaultLangKey, language);
    await prefs.setString(_defaultCurrencyKey, currency);
    _defaultLanguage = language;
    notifyListeners();
  }

  Future<Map<String, String>> getDefaultPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'language': prefs.getString(_defaultLangKey) ?? 'ไทย',
      'currency': prefs.getString(_defaultCurrencyKey) ?? 'THB',
    };
  }

  // =========================================================
  // AUTHENTICATION (หน้า Login / Register) - เชื่อมต่อกับ Firebase Authentication
  // =========================================================
  /// สมัครสมาชิกด้วยอีเมล/รหัสผ่านผ่าน Firebase Authentication โดยตรง
  /// (Firebase เป็นผู้ตรวจสอบอีเมลซ้ำ/ความยาวรหัสผ่านให้ ไม่ต้องเช็คเองในแอปอีก)
  /// จากนั้นจึงบันทึกข้อมูลโปรไฟล์ (ชื่อ/ภาษา/สกุลเงิน) ลง Firestore โดยใช้ uid เป็น id
  Future<String?> register(String name, String email, String password) async {
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw FirebaseAuthException(
          code: 'network-timeout',
          message: 'เชื่อมต่อ Firebase ไม่ได้ (หมดเวลา 15 วินาที) - เช็คการเชื่อมต่ออินเทอร์เน็ต',
        ),
      );
      final fbUser = cred.user;
      if (fbUser == null) return t('save_failed');
      await fbUser.updateDisplayName(name);

      final defaults = await getDefaultPreferences();
      final user = UserModel(
        id: fbUser.uid,
        name: name,
        email: email,
        createdAt: DateTime.now(),
        language: defaults['language']!,
        currency: defaults['currency']!,
      );
      await _db.insert('users', user.toMap());

      currentUser = user;
      _transactions.clear();
      _goals.clear();

      notifyListeners();
      return null; // สำเร็จ
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return t('email_in_use');
        case 'weak-password':
          return t('password_min_length');
        default:
          return e.message ?? t('save_failed');
      }
    } catch (e) {
      // เผื่อกรณี error ที่ไม่ใช่ FirebaseAuthException โดยตรง เช่น เขียน Firestore
      // ไม่สำเร็จ หรือเน็ตหลุด - ต้อง return ข้อความเสมอ ไม่ปล่อยให้ throw หลุดออกไป
      // ไม่งั้นหน้าสมัครสมาชิกจะค้างสถานะ loading ตลอดไปเพราะ setState ไม่ถูกเรียก
      return '${t('save_failed')}: $e';
    }
  }

  /// เข้าสู่ระบบด้วยอีเมล/รหัสผ่านผ่าน Firebase Authentication โดยตรง
  Future<String?> login(String email, String password) async {
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final fbUser = cred.user;
      if (fbUser == null) return t('login_error');

      final rows = await _db.query('users', where: 'id = ?', whereArgs: [fbUser.uid]);
      UserModel user;
      if (rows.isEmpty) {
        // เผื่อกรณีมีบัญชีใน Firebase Auth อยู่แล้วแต่ยังไม่มีโปรไฟล์ใน Firestore
        final defaults = await getDefaultPreferences();
        user = UserModel(
          id: fbUser.uid,
          name: fbUser.displayName ?? email.split('@').first,
          email: email,
          createdAt: DateTime.now(),
          language: defaults['language']!,
          currency: defaults['currency']!,
        );
        await _db.insert('users', user.toMap());
      } else {
        user = UserModel.fromMap(rows.first);
      }

      currentUser = user;
      await _loadUserData();

      final prefs = await SharedPreferences.getInstance();
      avatarPath = prefs.getString('avatar_path_${user.id}');

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (_) {
      return t('login_error');
    } catch (e) {
      return '${t('login_error')}: $e';
    }
  }

  /// เข้าสู่ระบบ/สมัครสมาชิกอัตโนมัติด้วยบัญชี Google
  /// คืนค่า null หากสำเร็จ หรือข้อความ error หากไม่สำเร็จ/ผู้ใช้ยกเลิก
  Future<String?> loginWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return t('login_error'); // ผู้ใช้กดยกเลิก

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final fbUser = userCred.user;
      if (fbUser == null || fbUser.email == null) return t('login_error');

      // ใช้ uid ของ Firebase Auth เป็น document id เสมอ (แหล่งอ้างอิงเดียวกับ
      // register/login แบบอีเมล-รหัสผ่าน) เพื่อไม่ให้บัญชี Google กับบัญชีอีเมลชนกัน
      final rows = await _db.query('users', where: 'id = ?', whereArgs: [fbUser.uid]);

      UserModel user;
      if (rows.isEmpty) {
        // ยังไม่เคยมีโปรไฟล์ -> สร้างให้อัตโนมัติ (Firebase Auth ดูแลเรื่องรหัสผ่านให้แล้ว)
        final defaults = await getDefaultPreferences();
        user = UserModel(
          id: fbUser.uid,
          name: fbUser.displayName ?? fbUser.email!.split('@').first,
          email: fbUser.email!,
          createdAt: DateTime.now(),
          language: defaults['language']!,
          currency: defaults['currency']!,
        );
        await _db.insert('users', user.toMap());
      } else {
        user = UserModel.fromMap(rows.first);
      }

      currentUser = user;
      await _loadUserData();

      final prefs = await SharedPreferences.getInstance();
      avatarPath = prefs.getString('avatar_path_${user.id}');

      notifyListeners();
      return null;
    } catch (e) {
      return '${t('login_error')}: $e';
    }
  }

  /// รีเซ็ตรหัสผ่านด้วยอีเมล (หน้า Forgot Password)
  /// ส่งอีเมลลิงก์รีเซ็ตรหัสผ่านผ่าน Firebase Authentication โดยตรง (sendPasswordResetEmail)
  /// ผู้ใช้จะตั้งรหัสผ่านใหม่จากลิงก์ในอีเมล ไม่ใช่กรอกในแอปอีกต่อไป
  /// คืนค่า null หากส่งอีเมลสำเร็จ หรือข้อความ error หากไม่พบบัญชีที่ใช้อีเมลนี้
  Future<String?> resetPassword(String email) async {
    try {
      final lang = currentLanguage == 'English' ? 'en' : 'th';
      final actionCodeSettings = ActionCodeSettings(
        url:
            'https://budgetmate-app-a94da.web.app/reset_password.html?lang=$lang',
        handleCodeInApp: false,
      );
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-email':
          return t('account_not_found');
        default:
          return e.message ?? t('account_not_found');
      }
    }
  }

  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    currentUser = null;
    _transactions.clear();
    _goals.clear();
    notifyListeners();
  }

  Future<void> updateProfile({String? name, String? language, String? currency}) async {
    if (currentUser == null) return;
    if (name != null) currentUser!.name = name;
    if (language != null) currentUser!.language = language;
    if (currency != null) currentUser!.currency = currency;
    await _db.update('users', currentUser!.toMap(), 'id = ?', [currentUser!.id]);
    notifyListeners();
  }

  /// เปิดตัวเลือกรูปภาพ (กล้อง/คลังภาพ) แล้วบันทึกไฟล์ลงเครื่องถาวร
  /// เก็บ path ไว้ใน SharedPreferences แยกตาม user id (ไม่ผูกกับตาราง users ใน SQLite
  /// เพื่อไม่ต้องแก้ schema เดิม) คืนค่า true หากเปลี่ยนรูปสำเร็จ
  Future<bool> pickAvatar({required bool fromCamera}) async {
    if (currentUser == null) return false;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null) return false;

    final dir = await getApplicationDocumentsDirectory();
    final ext = picked.path.contains('.') ? picked.path.split('.').last : 'jpg';
    final savedPath = '${dir.path}/avatar_${currentUser!.id}.$ext';

    // ลบไฟล์รูปเก่า (ถ้ามี) ก่อนเขียนทับ กันไฟล์ค้างเปลืองพื้นที่
    if (avatarPath != null) {
      final old = File(avatarPath!);
      if (await old.exists()) {
        try {
          await old.delete();
        } catch (_) {}
      }
    }

    await File(picked.path).copy(savedPath);
    avatarPath = savedPath;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatar_path_${currentUser!.id}', savedPath);

    notifyListeners();
    return true;
  }

  Future<void> removeAvatar() async {
    if (currentUser == null || avatarPath == null) return;
    final file = File(avatarPath!);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
    avatarPath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('avatar_path_${currentUser!.id}');
    notifyListeners();
  }

  /// เปลี่ยนธีมแอป (Light/Dark) - ใช้ทั่วทั้งแอปผ่าน MaterialApp.themeMode
  Future<void> toggleTheme() async {
    themeMode = themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, themeMode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  /// เปิด/ปิดการแจ้งเตือนเมื่อทำรายการสำเร็จ (เช่น banner "บันทึกสำเร็จ")
  Future<void> toggleSuccessNotes() async {
    successNotesEnabled = !successNotesEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_successNotesKey, successNotesEnabled);
    notifyListeners();
  }

  /// เปลี่ยนรหัสผ่าน (ต้องกรอกรหัสผ่านเดิมให้ถูกต้องก่อน) - หน้า Password & Security
  /// ยืนยันตัวตนซ้ำ (reauthenticate) กับ Firebase Authentication ด้วยรหัสผ่านเดิม
  /// ก่อนอัปเดตเป็นรหัสผ่านใหม่ (ผู้ใช้ที่ล็อกอินด้วย Google เท่านั้นที่จะไม่มีรหัสผ่านให้เปลี่ยน)
  Future<String?> changePassword(String currentPassword, String newPassword) async {
    if (currentUser == null) return t('please_login_first');
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null || fbUser.email == null) return t('please_login_first');

    try {
      final credential = EmailAuthProvider.credential(
        email: fbUser.email!,
        password: currentPassword,
      );
      await fbUser.reauthenticateWithCredential(credential);
      await fbUser.updatePassword(newPassword);
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return t('wrong_current_password');
        case 'weak-password':
          return t('password_min_length');
        default:
          return e.message ?? t('wrong_current_password');
      }
    }
  }

  // =========================================================
  // 1.3.1 ระบบฟังก์ชันบันทึกรายรับ-รายจ่าย
  // =========================================================
  Future<void> addTransaction({
    required CategoryType type,
    required double amount,
    required CategoryModel category,
    required DateTime date,
    String? note,
    String? description,
    String? receiptPath,
  }) async {
    if (currentUser == null) return;
    final tx = TransactionModel(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      category: category,
      date: date,
      note: note,
      description: description,
      receiptPath: receiptPath,
    );
    if (!offlineMode) {
      await _db.insert('transactions', tx.toMap(currentUser!.id));
    }
    _transactions.add(tx);
    notifyListeners();
  }

  Future<void> editTransaction(
    String id, {
    CategoryType? type,
    double? amount,
    CategoryModel? category,
    DateTime? date,
    String? note,
    String? description,
  }) async {
    if (currentUser == null) return;
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final updated = _transactions[index].copyWith(
      type: type,
      amount: amount,
      category: category,
      date: date,
      note: note,
      description: description,
    );
    _transactions[index] = updated;
    await _db.update('transactions', updated.toMap(currentUser!.id), 'id = ?', [id]);
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((t) => t.id == id);
    await _db.delete('transactions', 'id = ?', [id]);
    notifyListeners();
  }

  Future<CategoryModel> addCategory(String name, CategoryType type, IconData icon) async {
    final category = CategoryModel(id: _uuid.v4(), name: name, type: type, icon: icon);
    await _db.insert('categories', category.toMap());
    categories.add(category);
    notifyListeners();
    return category;
  }

  List<CategoryModel> categoriesByType(CategoryType type) =>
      categories.where((c) => c.type == type).toList();

  // =========================================================
  // 1.3.2 ระบบตั้งเป้าหมายการออม (Goal Saving)
  // =========================================================
  /// คืนค่า null หากบันทึกสำเร็จ หรือข้อความ error หากบันทึกไม่สำเร็จ (เช่น
  /// เชื่อมต่อฐานข้อมูลไม่ได้/หมดเวลา) เดิมเมธอดนี้ปล่อยให้ exception จาก _db.insert
  /// หลุดออกไปแบบ unhandled ทำให้แอป crash และหน้าจอผู้เรียกค้างสถานะ loading ตลอดไป
  Future<String?> addGoal({
    required String name,
    required double targetAmount,
    required DateTime targetDate,
    required IconData icon,
    double savedAmount = 0,
    String? note,
  }) async {
    if (currentUser == null) return t('please_login_first');
    final goal = GoalModel(
      id: _uuid.v4(),
      name: name,
      targetAmount: targetAmount,
      savedAmount: savedAmount,
      startDate: DateTime.now(),
      targetDate: targetDate,
      icon: icon,
      note: note,
    );
    try {
      await _db.insert('goals', goal.toMap(currentUser!.id));
    } catch (e) {
      return '${t('save_failed')}: $e';
    }
    _goals.add(goal);
    notifyListeners();
    return null;
  }

  /// เพิ่มเงินออมเข้าเป้าหมาย และอัปเดตสถานะอัตโนมัติเมื่อถึงเป้าหมาย
  /// หมายเหตุ: เมธอดนี้ไม่กระทบ Ledger Balance (ไม่สร้างรายจ่าย) — เก็บไว้เพื่อความเข้ากันได้ย้อนหลัง
  /// สำหรับการ "โอนเงินจริง" ที่ต้องหักยอดคงเหลือด้วย ให้ใช้ [transferToGoal] แทน
  Future<void> contributeToGoal(String goalId, double amount) async {
    final goal = _goals.firstWhere((g) => g.id == goalId);
    goal.savedAmount = (goal.savedAmount + amount).clamp(0, goal.targetAmount);
    if (goal.savedAmount >= goal.targetAmount) {
      goal.status = GoalStatus.completed;
    }
    if (currentUser != null) {
      await _db.update('goals', goal.toMap(currentUser!.id), 'id = ?', [goal.id]);
    }
    notifyListeners();
  }

  static const _goalSavingCategoryId = 'c17';

  /// หาหมวดหมู่ "เงินออม" ที่ใช้บันทึกรายจ่ายอัตโนมัติเมื่อโอนเงินเข้าเป้าหมาย
  /// สร้างให้อัตโนมัติถ้ายังไม่มี (เผื่อฐานข้อมูลเก่าที่ seed ไปก่อนเพิ่มหมวดนี้)
  Future<CategoryModel> _ensureGoalSavingCategory() async {
    final existing = categories.where(
        (c) => c.id == _goalSavingCategoryId || c.name == 'เงินออม');
    if (existing.isNotEmpty) return existing.first;

    final category = const CategoryModel(
      id: _goalSavingCategoryId,
      name: 'เงินออม',
      type: CategoryType.expense,
      icon: Icons.savings,
      description: 'หมวดหมู่รายจ่ายสำหรับการโอนเงินเข้าเป้าหมายการออม (สร้างอัตโนมัติ)',
      imagePath: 'assets/images/categories/c17.png',
    );
    await _db.insert('categories', category.toMap());
    categories.add(category);
    return category;
  }

  /// โอนเงิน "จริง" เข้าเป้าหมายการออม (ข้อ 1.3.2.1 แบบหักยอดจริง):
  /// 1) หักยอดจาก Ledger Balance โดยบันทึกเป็นรายการรายจ่ายอัตโนมัติ (หมวด "เงินออม")
  /// 2) เพิ่มยอดเงินออมสะสม (saved_amount) ของเป้าหมายพร้อมกัน
  /// คืนค่า null หากโอนสำเร็จ หรือข้อความ error หากทำไม่ได้ (เช่น ยอดคงเหลือไม่พอ)
  Future<String?> transferToGoal(String goalId, double amount, {String? note}) async {
    if (currentUser == null) return t('please_login_first');
    if (amount <= 0) return t('enter_valid_amount');

    final goalIndex = _goals.indexWhere((g) => g.id == goalId);
    if (goalIndex == -1) return t('goal_not_found');
    final goal = _goals[goalIndex];

    if (amount > balance) {
      return '${t('insufficient_ledger_prefix')} ฿${balance.toStringAsFixed(2)})';
    }

    // แก้บั๊ก: เดิมเมธอดนี้ไม่ตรวจว่าจำนวนที่โอนเกินยอดที่ยังขาดอยู่ของเป้าหมายหรือไม่
    // (ต่างจาก contributeToGoal ที่ clamp ค่า saved_amount ไว้) ทำให้ saved_amount
    // สามารถเกิน target_amount ได้แบบเงียบๆ เมื่อผู้ใช้กรอกจำนวนเกินที่ต้องการอีก
    final remaining = goal.targetAmount - goal.savedAmount;
    if (remaining > 0 && amount > remaining) {
      return '${t('amount_exceeds_prefix')} ฿${remaining.toStringAsFixed(2)})';
    }

    final category = await _ensureGoalSavingCategory();
    final tx = TransactionModel(
      id: _uuid.v4(),
      type: CategoryType.expense,
      amount: amount,
      category: category,
      date: DateTime.now(),
      note: note ?? 'โอนเงินเข้าเป้าหมาย: ${goal.name}',
      description: 'goal_transfer:${goal.id}',
    );

    final wasCompleted = goal.status == GoalStatus.completed;
    try {
      // 1) บันทึกรายจ่ายอัตโนมัติ (หักออกจาก Ledger Balance ทันทีเพราะ balance คำนวณจาก transactions)
      await _db.insert('transactions', tx.toMap(currentUser!.id));
      _transactions.add(tx);

      // 2) เพิ่มยอดออมสะสมของเป้าหมาย
      goal.savedAmount += amount;
      if (goal.savedAmount >= goal.targetAmount) {
        goal.status = GoalStatus.completed;
      }
      await _db.update('goals', goal.toMap(currentUser!.id), 'id = ?', [goal.id]);
    } catch (e) {
      // ชดเชยย้อนกลับ (compensating rollback) เนื่องจาก DBHelper ปัจจุบันไม่มี atomic transaction()
      // TODO: ถ้าต้องการความปลอดภัยสูงสุด ควรเพิ่มเมธอด runInTransaction ใน DBHelper
      // แล้วห่อ insert(transactions) + update(goals) ไว้ในทรานแซกชันเดียวของ SQLite จริง ๆ
      _transactions.removeWhere((t) => t.id == tx.id);
      await _db.delete('transactions', 'id = ?', [tx.id]);
      goal.savedAmount -= amount;
      goal.status = wasCompleted ? GoalStatus.completed : GoalStatus.inProgress;
      notifyListeners();
      return t('transfer_failed');
    }

    notifyListeners();
    return null;
  }

  Future<void> deleteGoal(String id) async {
    _goals.removeWhere((g) => g.id == id);
    await _db.delete('goals', 'id = ?', [id]);
    notifyListeners();
  }

  /// เป้าหมายที่ใกล้ถึงเป้า (ใช้แจ้งเตือนตามข้อ 1.3.2.2)
  List<GoalModel> get nearingGoals => _goals.where((g) => g.isNearTarget).toList();

  // =========================================================
  // 1.3.3 การแสดงผลข้อมูลทางการเงิน (คำนวณจากข้อมูลที่โหลดไว้ในหน่วยความจำ)
  // =========================================================
  double get totalIncome => _transactions
      .where((t) => t.type == CategoryType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpense => _transactions
      .where((t) => t.type == CategoryType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get balance => totalIncome - totalExpense;

  double monthlyTotal(CategoryType type, DateTime month) {
    return _transactions
        .where((t) =>
            t.type == type && t.date.year == month.year && t.date.month == month.month)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// ยอดรวมของวันใดวันหนึ่ง (ใช้กับกราฟที่เลือกดูแบบ "วัน")
  double dailyTotal(CategoryType type, DateTime day) {
    return _transactions
        .where((t) =>
            t.type == type &&
            t.date.year == day.year &&
            t.date.month == day.month &&
            t.date.day == day.day)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// ยอดรวมของปีใดปีหนึ่ง (ใช้กับกราฟที่เลือกดูแบบ "ปี")
  double yearlyTotal(CategoryType type, int year) {
    return _transactions
        .where((t) => t.type == type && t.date.year == year)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// สรุปรายรับ-รายจ่ายรายวัน ย้อนหลัง [days] วัน นับจาก [endDate] (ค่าเริ่มต้นคือวันนี้)
  /// ใช้เมื่อผู้ใช้เลือกดูกราฟแบบ "วัน" ในหน้า Home / Statistic
  List<MapEntry<DateTime, Map<String, double>>> dailySummary({int days = 7, DateTime? endDate}) {
    final end = endDate ?? DateTime.now();
    final result = <MapEntry<DateTime, Map<String, double>>>[];
    for (int i = days - 1; i >= 0; i--) {
      final day = DateTime(end.year, end.month, end.day - i);
      result.add(MapEntry(day, {
        'income': dailyTotal(CategoryType.income, day),
        'expense': dailyTotal(CategoryType.expense, day),
      }));
    }
    return result;
  }

  /// สรุปรายรับ-รายจ่ายรายเดือน ย้อนหลัง [months] เดือน นับจาก [endMonth] (ข้อ 1.3.3.1)
  /// [endMonth] ใช้แค่เดือน/ปีเป็นตัวอ้างอิง (ไม่สนใจวัน) ค่าเริ่มต้นคือเดือนปัจจุบัน
  /// เพิ่มพารามิเตอร์นี้เพื่อรองรับการ "เลือกเดือน/ปี" ย้อนหลังจากหน้า Home / Statistic
  List<MapEntry<DateTime, Map<String, double>>> monthlySummary({int months = 6, DateTime? endMonth}) {
    final now = endMonth ?? DateTime.now();
    final result = <MapEntry<DateTime, Map<String, double>>>[];
    for (int i = months - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      result.add(MapEntry(month, {
        'income': monthlyTotal(CategoryType.income, month),
        'expense': monthlyTotal(CategoryType.expense, month),
      }));
    }
    return result;
  }

  /// สรุปรายรับ-รายจ่ายรายปี ย้อนหลัง [years] ปี นับจาก [endYear] (ค่าเริ่มต้นคือปีปัจจุบัน)
  /// ใช้เมื่อผู้ใช้เลือกดูกราฟแบบ "ปี" ในหน้า Home / Statistic
  List<MapEntry<int, Map<String, double>>> yearlySummary({int years = 5, int? endYear}) {
    final end = endYear ?? DateTime.now().year;
    final result = <MapEntry<int, Map<String, double>>>[];
    for (int i = years - 1; i >= 0; i--) {
      final year = end - i;
      result.add(MapEntry(year, {
        'income': yearlyTotal(CategoryType.income, year),
        'expense': yearlyTotal(CategoryType.expense, year),
      }));
    }
    return result;
  }

  /// สัดส่วนเปอร์เซ็นต์รายรับ/รายจ่าย (ข้อ 1.3.3.2)
  Map<String, double> get incomeExpensePercentage {
    final total = totalIncome + totalExpense;
    if (total == 0) return {'income': 0, 'expense': 0};
    return {
      'income': (totalIncome / total) * 100,
      'expense': (totalExpense / total) * 100,
    };
  }

  /// สัดส่วนค่าใช้จ่ายแยกตามหมวดหมู่ สำหรับ Pie Chart หน้า Income/Expense
  Map<CategoryModel, double> expenseByCategory({DateTime? month}) {
    final Map<CategoryModel, double> map = {};
    for (final t in _transactions.where((t) => t.type == CategoryType.expense)) {
      if (month != null &&
          !(t.date.year == month.year && t.date.month == month.month)) {
        continue;
      }
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map;
  }

  // =========================================================
  // 1.3.4 ระบบวิเคราะห์พฤติกรรมผู้ใช้ (User Behavior Analysis)
  // =========================================================
  MapEntry<CategoryModel, double>? get mostSpentCategory {
    final map = expenseByCategory();
    if (map.isEmpty) return null;
    final entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.first;
  }

  MapEntry<CategoryModel, double>? get leastSpentCategory {
    final map = expenseByCategory();
    if (map.isEmpty) return null;
    final entries = map.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    return entries.first;
  }

  List<TransactionModel> transactionsForDay(DateTime day) {
    return transactions
        .where((t) =>
            t.date.year == day.year && t.date.month == day.month && t.date.day == day.day)
        .toList();
  }
}