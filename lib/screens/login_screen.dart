import 'package:budgetmate/screens/Forgot%20password%20screen.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import 'register_screen.dart';
import 'home_screen.dart';

/// หน้า Login (3.4.3) - เข้าสู่ระบบด้วยอีเมลและรหัสผ่าน (ตรวจสอบกับ SQLite จริง)
///
/// ปรับดีไซน์ให้เข้าชุดเดียวกับหน้า Register / Forgot Password:
/// - ใช้โครงหน้า HeaderIconBadge + title + subtitle เหมือนกันทั้ง 3 หน้า auth
/// - เปลี่ยนปุ่มสลับ "เข้าสู่ระบบ/สมัครสมาชิก" จากกล่องสีทึบ 2 กล่อง
///   มาเป็น pill segmented toggle แบบเดียวกับที่ใช้ทั่วแอป
///   (เทียบ _filterChip ใน history_screen.dart, _periodChip ใน period_selector.dart)
/// - ใช้ AppTextStyles.title ให้สัดส่วนตัวอักษรตรงกับหน้าอื่น
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _obscure = true;
  bool _googleLoading = false;

  Future<void> _handleLogin() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final service = context.read<DataService>();
    final error = await service.login(_emailCtrl.text.trim(), _passCtrl.text);

    if (!mounted) return;

    if (error == null) {
      Navigator.pushReplacement(
          context, noAnimationRoute(const HomeScreen()));
    } else {
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_googleLoading) return;
    setState(() {
      _googleLoading = true;
      _error = null;
    });

    final service = context.read<DataService>();
    final error = await service.loginWithGoogle();

    if (!mounted) return;

    if (error == null) {
      Navigator.pushReplacement(
          context, noAnimationRoute(const HomeScreen()));
    } else {
      setState(() {
        _googleLoading = false;
        _error = error;
      });
    }
  }

  void _goToRegister() {
    Navigator.push(context, noAnimationRoute(const RegisterScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final isThai = service.currentLanguage != 'English';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const HeaderIconBadge(icon: Icons.account_balance_wallet_rounded),
                const SizedBox(height: 20),
                Text(service.t('app_name'),
                    textAlign: TextAlign.center, style: AppTextStyles.title),
                const SizedBox(height: 6),
                Text(service.t('login_subtitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                const SizedBox(height: 28),

                // สลับ เข้าสู่ระบบ/สมัครสมาชิก แบบ pill segmented เดียวกับที่ใช้ทั่วแอป
                _AuthTabToggle(
                  loginLabel: service.t('login'),
                  registerLabel: service.t('register'),
                  onRegisterTap: _goToRegister,
                ),

                const SizedBox(height: 24),
                AppTextField(
                  controller: _emailCtrl,
                  hint: service.t('email_hint'),
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _passCtrl,
                  hint: service.t('password_hint'),
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscure,
                  toggleObscure: () => setState(() => _obscure = !_obscure),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  MessageBanner(text: _error!),
                ],
                const SizedBox(height: 22),
                PrimaryButton(
                  label: service.t('sign_in'),
                  loading: _loading,
                  onPressed: _handleLogin,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(isThai ? 'หรือ' : 'or',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                    ),
                    Expanded(child: Divider(color: AppColors.border)),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      side: BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    onPressed: _googleLoading ? null : _handleGoogleLogin,
                    icon: _googleLoading
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.textPrimary))
                        : Image.asset('assets/images/google_logo.png', height: 20, width: 20),
                    label: Text(
                        isThai ? 'เข้าสู่ระบบด้วย Google' : 'Continue with Google',
                        style: TextStyle(
                            color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(
                        context, noAnimationRoute(const ForgotPasswordScreen())),
                    child: Text(service.t('forgot_password_q'),
                        style: TextStyle(
                            color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill segmented toggle "เข้าสู่ระบบ / สมัครสมาชิก" — ใช้โทนสี/รูปแบบเดียวกับ
/// _typeToggle ใน add_income_expense_screen.dart (แถบพื้นหลัง AppColors.surface
/// มีเส้นขอบ + แท่งไฮไลต์ AppColors.accentDeep เลื่อนได้) เพื่อให้หน้า Login
/// ใช้ภาษาภาพเดียวกับส่วนอื่นของแอป แทนกล่องสีทึบสองกล่องแบบเดิม
///
/// เนื่องจากหน้านี้อยู่บน "เข้าสู่ระบบ" อยู่แล้วเสมอ (ฝั่งซ้ายไฮไลต์ค้าง) และการแตะ
/// ฝั่ง "สมัครสมาชิก" จะนำทางออกไปหน้า RegisterScreen แทนการสลับ state ภายใน
class _AuthTabToggle extends StatelessWidget {
  final String loginLabel;
  final String registerLabel;
  final VoidCallback onRegisterTap;

  const _AuthTabToggle({
    required this.loginLabel,
    required this.registerLabel,
    required this.onRegisterTap,
  });

  @override
  Widget build(BuildContext context) {
    const height = 46.0;
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accentDeep,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Center(
                  child: Text(loginLabel,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onRegisterTap,
                  child: Center(
                    child: Text(registerLabel,
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}