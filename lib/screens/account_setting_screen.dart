import 'dart:io';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';

const List<String> _languageOptions = ['ไทย', 'English'];

/// หน้า Account Setting (3.4.5) - จัดการข้อมูลบัญชีผู้ใช้งานและการตั้งค่าแอป
class AccountSettingScreen extends StatelessWidget {
  const AccountSettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final user = service.currentUser;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(service.t('account_setting_title'),
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                _AvatarPicker(service: service),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? '-',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(user?.email ?? '-',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionLabel(service.t('account_section')),
          _tile(context, service.t('manage_profile'),
              icon: Icons.badge_outlined, onTap: () => _editNameDialog(context, service)),
          _tile(context, service.t('password_security'),
              icon: Icons.lock_outline_rounded,
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()))),
          _tile(context, service.t('language'),
              icon: Icons.language_rounded,
              trailing: user?.language ?? 'ไทย',
              onTap: () => _languageDialog(context, service)),
          const SizedBox(height: 20),
          _sectionLabel(service.t('preferences_section')),
          _tile(context, service.t('about_us'),
              icon: Icons.info_outline_rounded, onTap: () => _aboutDialog(context, service)),
          _switchTile(
            title: service.t('theme'),
            icon: Icons.dark_mode_outlined,
            subtitle: service.themeMode == ThemeMode.dark ? service.t('theme_dark') : service.t('theme_light'),
            value: service.themeMode == ThemeMode.dark,
            onChanged: (_) => service.toggleTheme(),
          ),
          _switchTile(
            title: service.t('success_notes'),
            icon: Icons.notifications_outlined,
            subtitle: service.successNotesEnabled ? service.t('enabled') : service.t('disabled'),
            value: service.successNotesEnabled,
            onChanged: (_) => service.toggleSuccessNotes(),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: BorderSide(color: AppColors.danger.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              onPressed: () async {
                await service.logout();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false);
              },
              child: Text(service.t('logout'), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 4),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(text, style: AppTextStyles.heading),
      );

  Widget _tile(BuildContext context, String title,
      {IconData? icon, String? trailing, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        onTap: onTap,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: icon != null ? Icon(icon, color: AppColors.textSecondary, size: 21) : null,
          title: Text(title, style: TextStyle(fontSize: 14.5, color: AppColors.textPrimary)),
          trailing: trailing != null
              ? Text(trailing, style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
              : Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ),
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required IconData icon,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: AppColors.textSecondary, size: 21),
          title: Text(title, style: TextStyle(fontSize: 14.5, color: AppColors.textPrimary)),
          subtitle: Text(subtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
          trailing: Switch(
            value: value,
            activeColor: AppColors.ink,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  void _editNameDialog(BuildContext context, DataService service) {
    final ctrl = TextEditingController(text: service.currentUser?.name);
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (dialogContext) {
        bool saving = false;
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> save() async {
              final name = ctrl.text.trim();
              if (name.isEmpty) {
                setState(() => errorText = service.t('enter_username'));
                return;
              }
              setState(() {
                saving = true;
                errorText = null;
              });
              await service.updateProfile(name: name);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            }

            return Dialog(
              backgroundColor: AppColors.bg,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.accentBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.badge_outlined, color: AppColors.ink, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(service.t('edit_username'),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: saving ? null : () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(service.t('display_name'),
                        style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: ctrl,
                      hint: service.t('username_hint'),
                      icon: Icons.person_outline_rounded,
                      autofocus: true,
                      errorText: errorText,
                      onChanged: (_) {
                        if (errorText != null) setState(() => errorText = null);
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.md)),
                            ),
                            onPressed: saving ? null : () => Navigator.pop(dialogContext),
                            child: Text(service.t('cancel'),
                                style:
                                    TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.ink,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.md)),
                            ),
                            onPressed: saving ? null : save,
                            child: saving
                                ? SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: AppColors.inkOn))
                                : Text(service.t('save_action'), style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.inkOn)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _languageDialog(BuildContext context, DataService service) {
    const flags = {'ไทย': '🇹🇭', 'English': '🇬🇧'};

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.bg,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.accentBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.language_rounded, color: AppColors.ink, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(service.t('choose_language'),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._languageOptions.map((lang) {
                  final selected = (service.currentUser?.language ?? 'ไทย') == lang;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: selected ? AppColors.accentBg : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        onTap: () async {
                          await service.setLanguage(lang);
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: selected ? AppColors.ink : AppColors.border,
                              width: selected ? 1.4 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(flags[lang] ?? '🏳️', style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(lang,
                                    style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                                        color: selected ? AppColors.ink : AppColors.textPrimary)),
                              ),
                              if (selected)
                                Icon(Icons.check_circle_rounded,
                                    color: AppColors.ink, size: 20)
                              else
                                Icon(Icons.circle_outlined,
                                    color: AppColors.border, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _aboutDialog(BuildContext context, DataService service) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(service.t('about_title'), style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          service.t('about_body'),
          style: TextStyle(height: 1.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext), child: Text(service.t('close'))),
        ],
      ),
    );
  }
}

/// รูปโปรไฟล์ที่แตะเพื่อเปลี่ยนได้ (ถ่ายรูปใหม่ / เลือกจากคลังภาพ / ลบรูป)
class _AvatarPicker extends StatelessWidget {
  final DataService service;
  const _AvatarPicker({required this.service});

  @override
  Widget build(BuildContext context) {
    final path = service.avatarPath;
    final hasImage = path != null && File(path).existsSync();

    return GestureDetector(
      onTap: () => _showPickerSheet(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.accentBg,
            backgroundImage: hasImage ? FileImage(File(path)) : null,
            child: hasImage
                ? null
                : Icon(Icons.person, size: 28, color: AppColors.ink),
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.accentDeep,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showPickerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) {
        final hasImage = service.avatarPath != null;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.photo_camera_outlined, color: AppColors.textPrimary),
                  title: Text(service.t('take_photo'), style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await service.pickAvatar(fromCamera: true);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library_outlined, color: AppColors.textPrimary),
                  title: Text(service.t('choose_from_gallery'), style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await service.pickAvatar(fromCamera: false);
                  },
                ),
                if (hasImage)
                  ListTile(
                    leading: Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    title: Text(service.t('remove_photo'), style: TextStyle(color: AppColors.danger)),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await service.removeAvatar();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}