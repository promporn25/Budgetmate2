import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import 'login_screen.dart';
import 'language_setup_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  Future<void> _handleRegister() async {
    if (_loading) return;
    final service = context.read<DataService>();

    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = service.t('password_mismatch'));
      return;
    }
    if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = service.t('fill_all_fields'));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    String? error;
    try {
      error = await service.register(
          _nameCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text);
    } catch (e) {
      error = '${service.t('save_failed')}: $e';
    }

    if (!mounted) return;

    if (error == null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LanguageSetupScreen()),
        (route) => false,
      );
    } else {
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const HeaderIconBadge(icon: Icons.person_add_alt_1_rounded),
                const SizedBox(height: 20),
                Text(service.t('create_account'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.title),
                const SizedBox(height: 6),
                Text(service.t('register_subtitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                const SizedBox(height: 28),
                AppTextField(
                  controller: _nameCtrl,
                  hint: service.t('name_hint'),
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 14),
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
                  obscureText: _obscurePass,
                  toggleObscure: () => setState(() => _obscurePass = !_obscurePass),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _confirmCtrl,
                  hint: service.t('confirm_password_hint'),
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscureConfirm,
                  toggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  MessageBanner(text: _error!),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: service.t('sign_up'),
                  loading: _loading,
                  onPressed: _handleRegister,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : _goToLogin,
                    child: Text.rich(
                      TextSpan(
                        text: service.t('already_have_account'),
                        style: TextStyle(color: AppColors.textSecondary),
                        children: [
                          TextSpan(
                            text: service.t('login'),
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}