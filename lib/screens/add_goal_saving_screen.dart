import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';


const List<IconData> _goalIcons = [
  Icons.restaurant, Icons.local_cafe, Icons.home, Icons.directions_car,
  Icons.receipt_long, Icons.shopping_bag, Icons.card_giftcard,
  Icons.flight, Icons.spa, Icons.music_note, Icons.sports_soccer,
  Icons.pets, Icons.school,
];

/// หน้า Add Goal Saving (3.4.12) - เพิ่มเป้าหมายการออมเงินใหม่ลง SQLite
class AddGoalSavingScreen extends StatefulWidget {
  const AddGoalSavingScreen({super.key});

  @override
  State<AddGoalSavingScreen> createState() => _AddGoalSavingScreenState();
}

class _AddGoalSavingScreenState extends State<AddGoalSavingScreen> {
  // ความสูงคงที่ของแผงปุ่มตัวเลขที่จะเลื่อนขึ้นมาจากด้านล่าง
  // (ดีไซน์เดียวกับหน้า Add Income/Expense)
  static const double _numpadHeight = 300;
  static const Duration _numpadAnim = Duration(milliseconds: 260);

  IconData _selectedIcon = _goalIcons.first;
  final _nameCtrl = TextEditingController();
  String _amountText = '';
  DateTime _targetDate = DateTime.now().add(const Duration(days: 180));
  bool _saving = false;

  // true เมื่อผู้ใช้กำลังจะพิมพ์จำนวนเงิน -> โชว์แป้นตัวเลข + เคอร์เซอร์กระพริบ
  bool _showNumpad = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _openNumpad() {
    // เอา focus ออกจากช่องชื่อเป้าหมาย
    FocusScope.of(context).unfocus();

    // ซ่อน keyboard ของมือถือ
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');

    setState(() {
      _showNumpad = true;
    });
  }

  void _closeNumpad() {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');

    if (_showNumpad) {
      setState(() {
        _showNumpad = false;
      });
    }
  }

  void _finishAmountInput() {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');

    setState(() {
      _showNumpad = false;
    });
  }

  void _pressDigit(String d) {
    setState(() {
      if (d == '.' && _amountText.contains('.')) return;
      _amountText += d;
    });
  }

  void _backspace() {
    if (_amountText.isEmpty) return;
    setState(() => _amountText = _amountText.substring(0, _amountText.length - 1));
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = double.tryParse(_amountText) ?? 0;
    final service = context.read<DataService>();
    if (_nameCtrl.text.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(service.t('fill_name_and_amount'))));
      return;
    }

    setState(() => _saving = true);

    final error = await service.addGoal(
          name: _nameCtrl.text,
          targetAmount: amount,
          targetDate: _targetDate,
          icon: _selectedIcon,
        );

    if (!mounted) return;

    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final panelHeight = _numpadHeight + bottomInset;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(service.t('goal_saving'),
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                : Text(service.t('save'),
                    style: TextStyle(
                        color: AppColors.ink, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ----- เนื้อหาหลักของหน้า -----
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppTextField(
                            controller: _nameCtrl,
                            hint: service.t('goal_name_hint'),
                            icon: Icons.flag_outlined,
                          ),
                          const SizedBox(height: 18),
                          Text(service.t('categories'), style: AppTextStyles.heading),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 14,
                            runSpacing: 12,
                            children: _goalIcons.map((icon) {
                              final selected = icon == _selectedIcon;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedIcon = icon),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  child: CircleAvatar(
                                    radius: 26,
                                    backgroundColor: selected ? AppColors.accentDeep : AppColors.surface,
                                    child: Icon(icon,
                                        size: 24, color: selected ? Colors.white : AppColors.textSecondary),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),
                          AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.event_outlined, color: AppColors.textSecondary),
                              title: Text(service.t('target_date_label'),
                                  style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary)),
                              subtitle: Text('${_targetDate.day}/${_targetDate.month}/${_targetDate.year}',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                              onTap: () async {
                                _closeNumpad();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _targetDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                                );
                                if (picked != null) setState(() => _targetDate = picked);
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  // แถบจำนวนเงิน: แตะเพื่อเปิดแป้นตัวเลข พร้อมเคอร์เซอร์กระพริบระหว่างพิมพ์
                  // (ดีไซน์เดียวกับหน้า Add Income/Expense)
                  _amountDisplay(),
                  // จองพื้นที่ด้านล่างเท่ากับความสูงแป้นตัวเลข เมื่อแป้นถูกเปิดอยู่
                  AnimatedContainer(
                    duration: _numpadAnim,
                    curve: Curves.easeOutCubic,
                    height: _showNumpad ? panelHeight : bottomInset + 8,
                  ),
                ],
              ),
            ),
          ),

          // ----- ฉากทึบใส สำหรับแตะนอกพื้นที่แป้นตัวเลขเพื่อปิดแป้น -----
          if (_showNumpad)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeNumpad,
                child: Container(color: Colors.transparent),
              ),
            ),

          // ----- แผงปุ่มตัวเลข เลื่อนขึ้นจากด้านล่าง เฉพาะตอนต้องการพิมพ์จำนวนเงิน -----
          AnimatedPositioned(
            duration: _numpadAnim,
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: _showNumpad ? 0 : -panelHeight,
            child: _numpadPanel(bottomInset),
          ),
        ],
      ),
    );
  }

  // กล่องแสดง/กรอกจำนวนเงิน: มีกรอบสีเดียวกับช่องอื่นๆ, มีลายน้ำตอนยังไม่กรอก,
  // และเคอร์เซอร์กระพริบอยู่ "หน้า" สัญลักษณ์ ฿ ระหว่างที่กำลังพิมพ์
  Widget _amountDisplay() {
    final service = context.read<DataService>();
    final showPlaceholder = !_showNumpad && _amountText.isEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openNumpad,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: _showNumpad ? AppColors.accentDeep : AppColors.border,
            width: _showNumpad ? 1.4 : 1,
          ),
        ),
        child: showPlaceholder
            ? Align(
                alignment: Alignment.centerRight,
                child: Text(
                  service.t('enter_valid_amount'),
                  style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _amountText,
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      if (_showNumpad) ...[
                        const SizedBox(width: 3),
                        _BlinkingCursor(color: AppColors.accentDeep, height: 24),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        '฿',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  if (_showNumpad) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _finishAmountInput,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: AppColors.accentDeep, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 23),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  // แผงปุ่มตัวเลขทั้งชุด (ความสูงคงที่ ลอยขึ้นมาจากขอบล่างจอ)
  Widget _numpadPanel(double bottomInset) {
    return Material(
      color: AppColors.bg,
      elevation: 16,
      shadowColor: Colors.black.withOpacity(0.15),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      child: SizedBox(
        height: _numpadHeight + bottomInset,
        child: Column(
          children: [
            const SizedBox(height: 10),
            // แถบจับเล็กๆ ด้านบน ให้ดูเหมือนแผ่นเลื่อนขึ้นมา (bottom sheet)
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(child: _numPad()),
            SizedBox(height: bottomInset),
          ],
        ),
      ),
    );
  }

  Widget _numPad() {
    const rows = [
      ['7', '8', '9'],
      ['4', '5', '6'],
      ['1', '2', '3'],
      ['.', '0', '⌫'],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: rows
            .map((row) => Expanded(
                  child: Row(
                    children: row
                        .map((key) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                child: Material(
                                  color: _keyBg(key),
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                    onTap: () => key == '⌫' ? _backspace() : _pressDigit(key),
                                    child: Center(
                                      child: Text(key,
                                          style: TextStyle(
                                              fontSize: 24, fontWeight: FontWeight.w600, color: _keyFg(key))),
                                    ),
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Color _keyBg(String key) {
    switch (key) {
      case '⌫':
        return const Color(0xFFDCEEF7);
      case '.':
        return const Color(0xFFFFF3D2);
      default:
        return AppColors.surface;
    }
  }

  Color _keyFg(String key) {
    switch (key) {
      case '⌫':
        return const Color(0xFF80A1D4);
      case '.':
        return const Color(0xFFC79A3B);
      default:
        return AppColors.textPrimary;
    }
  }
}

/// เคอร์เซอร์กระพริบ (เหมือนเคอร์เซอร์พิมพ์ข้อความ) ใช้แสดงต่อท้ายจำนวนเงิน
/// ระหว่างที่แป้นตัวเลขเปิดอยู่ ให้ผู้ใช้รู้ว่ากำลังอยู่ในโหมดพิมพ์
/// (คลาสเดียวกับที่ใช้ในหน้า Add Income/Expense)
class _BlinkingCursor extends StatefulWidget {
  final Color color;
  final double height;
  const _BlinkingCursor({required this.color, required this.height});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2.5,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}