import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ธีมกลางของแอป BUDGETMATE — v2 "Cute Fintech" redesign
///
/// Palette เดิม (9FBAF1 / FDFDF5 / 3D568F / EAF3B2) ถูกแทนที่ด้วยโทน
/// pastel lavender + peach ที่ให้ความรู้สึก friendly / modern / calm
/// มากขึ้น แต่ **ทุก getter ชื่อเดิมยังอยู่ครบ** ดังนั้นทุกหน้าที่เรียก
/// AppColors.xxx / AppCard / PrimaryButton / AppTextField ฯลฯ จะได้ดีไซน์
/// ใหม่ทันทีโดยไม่ต้องแก้ layout ของแต่ละหน้าเลย
///
/// AppColors.brightness ถูกตั้งค่าจาก DataService (themeMode) เหมือนเดิม
class AppColors {
  AppColors._();

  static Brightness brightness = Brightness.light;
  static bool get _dark => brightness == Brightness.dark;

  // ---- สีหลัก (Primary: soft muted purple / lavender) ----
  static Color get ink => _dark ? const Color(0xFFD9CBFF) : const Color(0xFF6C5BD1);
  static Color get inkOn => _dark ? const Color(0xFF221A3D) : Colors.white; // ตัวอักษรบนปุ่มพื้น ink
  static Color get accent => const Color(0xFFC9BEFB); // lavender พาสเทล
  static Color get accentAlt => const Color(0xFFFFD9B8); // peach พาสเทล
  static Color get accentDeep => const Color(0xFF6C5BD1); // ม่วงเข้ม (คงที่ไม่สลับโหมด, ใช้เป็น brand primary)

  static Color get accentBg => _dark ? const Color(0xFF322A55) : const Color(0xFFEFEAFE);
  static Color get accentAltBg => _dark ? const Color(0xFF473722) : const Color(0xFFFFF1E0);

  // ---- พื้นหลัง/พื้นผิว (warm off-white, ไม่ใช้ #FFFFFF ล้วน) ----
  static Color get bg => _dark ? const Color(0xFF17131F) : const Color(0xFFFBF8FF);
  static Color get surface => _dark ? const Color(0xFF221D33) : const Color(0xFFF3EEFC);
  static Color get surfaceAlt => _dark ? const Color(0xFF2B2440) : const Color(0xFFFFF8EF);
  static Color get card => _dark ? const Color(0xFF221D33) : const Color(0xFFF6F1FD);
  static Color get border => _dark ? const Color(0xFF3A3153) : const Color(0xFFE6DFF7);

  // ---- ตัวอักษร ----
  static Color get textPrimary => _dark ? const Color(0xFFF6F3FC) : const Color(0xFF362C55);
  static Color get textSecondary => _dark ? const Color(0xFFB7ADD1) : const Color(0xFF7C7299);
  static Color get textMuted => _dark ? const Color(0xFF7A7098) : const Color(0xFFB6AED4);

  // ---- สถานะ (pastel, ไม่ฉูดฉาด) ----
  static Color get success => _dark ? const Color(0xFF8FE0B4) : const Color(0xFF4FAE79);
  static Color get successBg => _dark ? const Color(0xFF203A2E) : const Color(0xFFE3F7EC);
  static Color get danger => _dark ? const Color(0xFFF0A6A0) : const Color(0xFFE0716A);
  static Color get dangerBg => _dark ? const Color(0xFF3E2726) : const Color(0xFFFDEAE8);
  static Color get income => _dark ? const Color(0xFFA6E8C2) : const Color(0xFF3F9E6C);
  static Color get incomeBg => _dark ? const Color(0xFF223B2C) : const Color(0xFFE4F6EB);
  static Color get expense => _dark ? const Color(0xFFF3AFA0) : const Color(0xFFD97862);
  static Color get expenseBg => _dark ? const Color(0xFF3E2B24) : const Color(0xFFFCEBE3);

  // เข้ากันได้ย้อนหลัง
  static Color get shadow => const Color(0xFF6C5BD1).withOpacity(_dark ? 0.28 : 0.10);
}

class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const pill = 999.0;
}

class AppTextStyles {
  // ฟอนต์แนะนำ: 'Poppins' / 'Nunito' (ละติน) + 'Prompt' (ไทย)
  // ถ้าเพิ่ม font family ใหม่ใน pubspec.yaml แล้ว เปลี่ยนค่า fontFamily
  // ด้านล่างนี้ทีเดียวจะมีผลกับทั้งแอป (ตอนนี้ยังคง 'Roboto' ไว้เป็นค่า
  // ปลอดภัยเผื่อยังไม่ได้ผูกฟอนต์ใหม่)
  static const String _fontFamily = 'Roboto';

  static TextStyle get title => TextStyle(
      fontFamily: _fontFamily,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: AppColors.textPrimary);
  static TextStyle get heading => TextStyle(
      fontFamily: _fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary);
  static TextStyle get label => TextStyle(
      fontFamily: _fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary);
  static TextStyle get hint =>
      TextStyle(fontFamily: _fontFamily, color: AppColors.textMuted, fontSize: 14);
  static TextStyle get caption =>
      TextStyle(fontFamily: _fontFamily, color: AppColors.textSecondary, fontSize: 12.5);

  /// ใช้กับตัวเลขยอดเงินก้อนใหญ่ (balance) — เด่น อ่านง่าย
  static TextStyle get amountLarge => TextStyle(
      fontFamily: _fontFamily,
      fontSize: 30,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: AppColors.textPrimary);
}

/// สร้าง ThemeData ของแอปสำหรับ MaterialApp(theme:, darkTheme:, themeMode:)
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF17131F) : const Color(0xFFFBF8FF);
    final ink = isDark ? const Color(0xFFD9CBFF) : const Color(0xFF6C5BD1);
    final surface = isDark ? const Color(0xFF221D33) : const Color(0xFFF3EEFC);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dialogBackgroundColor: isDark ? const Color(0xFF221D33) : Colors.white,
      splashFactory: InkRipple.splashFactory,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: const Color(0xFF6C5BD1),
        onPrimary: Colors.white,
        secondary: const Color(0xFFFFD9B8),
        onSecondary: const Color(0xFF3E2B10),
        error: isDark ? const Color(0xFFF0A6A0) : const Color(0xFFE0716A),
        onError: Colors.white,
        surface: surface,
        onSurface: isDark ? const Color(0xFFF6F3FC) : const Color(0xFF362C55),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
            color: isDark ? const Color(0xFFF6F3FC) : const Color(0xFF362C55),
            fontSize: 17,
            fontWeight: FontWeight.w700),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bg,
        selectedItemColor: ink,
        unselectedItemColor: isDark ? const Color(0xFF7A7098) : const Color(0xFFB6AED4),
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? const Color(0xFFFFD9B8) : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? const Color(0xFF6C5BD1) : null),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      fontFamily: 'Roboto',
    );
  }
}

/// การ์ดพื้นฐานที่ใช้ซ้ำได้ทั่วแอป
/// v2: มุมโค้งมากขึ้น + soft shadow แทนพื้นแบนล้วน + press animation เบาๆ
/// เมื่อมี onTap (กดแล้วยุบเล็กน้อยแบบนุ่มนวล ไม่เด้งเยอะ)
class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (widget.onTap == null) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      width: double.infinity,
      padding: widget.padding,
      transform: Matrix4.identity()..scale(_pressed ? 0.985 : 1.0),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
            spreadRadius: -8,
          ),
        ],
      ),
      child: widget.child,
    );

    if (widget.onTap == null) return content;
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: widget.onTap,
          splashColor: AppColors.accent.withOpacity(0.15),
          highlightColor: AppColors.accent.withOpacity(0.08),
          child: content,
        ),
      ),
    );
  }
}

/// ปุ่มหลักของแอป — พื้น ink (ม่วง lavender เข้ม), มุมโค้งนุ่ม,
/// มี scale animation ตอนกดเบาๆ (micro-interaction)
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? color;
  final double height;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.color,
    this.height = 52,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.color ?? AppColors.ink;
    final fg = AppColors.inkOn;
    final enabled = !widget.loading && widget.onPressed != null;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: SizedBox(
          width: double.infinity,
          height: widget.height,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: bg,
              disabledBackgroundColor: bg.withOpacity(0.5),
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            onPressed: widget.loading ? null : widget.onPressed,
            child: widget.loading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : Text(widget.label,
                    style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

/// ฟิลด์กรอกข้อความสไตล์เดียวกันทั้งแอป — พื้น pastel, ไม่มีเส้นขอบปกติ,
/// โฟกัสด้วยขอบ lavender นุ่มๆ
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool obscureText;
  final VoidCallback? toggleObscure;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool autofocus;
  final String? prefixText;
  final String? errorText;
  final TextStyle? style;
  final TextAlign textAlign;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.obscureText = false,
    this.toggleObscure,
    this.keyboardType,
    this.maxLines = 1,
    this.autofocus = false,
    this.prefixText,
    this.errorText,
    this.style,
    this.textAlign = TextAlign.start,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      autofocus: autofocus,
      textAlign: textAlign,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      cursorColor: AppColors.ink,
      style: style ?? TextStyle(fontSize: 15, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.hint,
        prefixText: prefixText,
        prefixStyle: style ?? TextStyle(fontSize: 15, color: AppColors.textPrimary),
        prefixIcon: icon != null ? Icon(icon, color: AppColors.textSecondary, size: 21) : null,
        suffixIcon: toggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: toggleObscure,
              )
            : null,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.danger, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.accentDeep, width: 1.6),
        ),
        errorText: errorText,
        errorStyle: TextStyle(color: AppColors.danger, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
    );
  }
}

/// แบนเนอร์ error/success ใช้ซ้ำได้ทุกฟอร์ม
class MessageBanner extends StatelessWidget {
  final String text;
  final bool isError;

  const MessageBanner({super.key, required this.text, this.isError = true});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.danger : AppColors.success;
    final bg = isError ? AppColors.dangerBg : AppColors.successBg;
    final icon = isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13, height: 1.35))),
        ],
      ),
    );
  }
}

/// ไอคอนวงกลมหัวเรื่อง (ใช้กับหน้า auth/ฟอร์มที่อยากมี visual anchor ด้านบน)
/// v2: เพิ่มวงแหวนพาสเทลจางๆ รอบนอกให้ดูนุ่มนวลขึ้นเล็กน้อย
class HeaderIconBadge extends StatelessWidget {
  final IconData icon;
  final Color? background;
  final Color? iconColor;

  const HeaderIconBadge({super.key, required this.icon, this.background, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 92,
        height: 92,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: (background ?? AppColors.accentBg).withOpacity(0.55),
          shape: BoxShape.circle,
        ),
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: background ?? AppColors.accentBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 36, color: iconColor ?? AppColors.ink),
        ),
      ),
    );
  }
}

/// ป้ายกลมๆ ว่าง (empty state) ใช้ตรงกลางลิสต์ที่ยังไม่มีข้อมูล
/// v2: ไอคอนอยู่ในวงกลมพาสเทลนุ่มๆ แทนไอคอนลอยเฉยๆ
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const EmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(color: AppColors.accentBg, shape: BoxShape.circle),
            child: Icon(icon, size: 30, color: AppColors.ink.withOpacity(0.7)),
          ),
          const SizedBox(height: 14),
          Text(text, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}