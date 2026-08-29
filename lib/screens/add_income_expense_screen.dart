import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../models/category_model.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import 'home_screen.dart';
import 'income_expense_screen.dart';

const List<IconData> _customCategoryIcons = [
  Icons.category_outlined, Icons.restaurant, Icons.local_cafe, Icons.home,
  Icons.directions_car, Icons.receipt_long, Icons.shopping_bag, Icons.card_giftcard,
  Icons.flight, Icons.spa, Icons.music_note, Icons.sports_soccer, Icons.pets,
  Icons.school, Icons.payments, Icons.trending_up, Icons.card_membership,
  Icons.savings, Icons.fastfood, Icons.local_hospital, Icons.build,
  Icons.pets_outlined, Icons.celebration, Icons.wifi, Icons.subscriptions,
];

// วงกลมสีพาสเทลสลับให้แต่ละหมวดหมู่ที่ยังไม่ถูกเลือก ให้ดูมีสีสันน่ารักตามดีไซน์อ้างอิง
const List<Color> _categoryTint = [
  Color(0xFFDCEEF7), // ฟ้าอ่อน (C1E4F3)
  Color(0xFFF6E1E7), // ชมพูอ่อน (C08B9D)
  Color(0xFFFFF3D2), // เหลืองอ่อน (FFE698)
  Color(0xFFDCE4F2), // น้ำเงินอ่อน (3D568F)
  Color(0xFFE1EFF8), // ฟ้ากลางอ่อน (80A1D4)
];
const List<Color> _categoryTintIcon = [
  Color(0xFF80A1D4),
  Color(0xFFC08B9D),
  Color(0xFFC79A3B),
  Color(0xFF3D568F),
  Color(0xFF5C86C4),
];

/// หน้า Add Income/Expense (3.4.10)
class AddIncomeExpenseScreen extends StatefulWidget {
  const AddIncomeExpenseScreen({super.key});

  @override
  State<AddIncomeExpenseScreen> createState() => _AddIncomeExpenseScreenState();
}

class _AddIncomeExpenseScreenState extends State<AddIncomeExpenseScreen> {
  // ความสูงคงที่ของแผงปุ่มตัวเลขที่จะเลื่อนขึ้นมาจากด้านล่าง
  static const double _numpadHeight = 300;
  static const Duration _numpadAnim = Duration(milliseconds: 260);

  CategoryType _type = CategoryType.income;
  CategoryModel? _selectedCategory;
  String _amountText = '';
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  // true เมื่อผู้ใช้กำลังจะพิมพ์จำนวนเงิน -> โชว์แป้นตัวเลข + เคอร์เซอร์กระพริบ
  bool _showNumpad = false;

  String? _editingId;
  List<Map<String, dynamic>> _tempTransactions = [];
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _openNumpad() {
  // เอา focus ออกจากช่องหมายเหตุ
  FocusScope.of(context).unfocus();

  // ซ่อน keyboard ของมือถือ
  SystemChannels.textInput.invokeMethod<void>('TextInput.hide');

  setState(() {
    _showNumpad = true;
  });
}

void _closeNumpad() {
  // เอา focus ออกจาก TextField ทุกตัว
  FocusScope.of(context).unfocus();

  // ซ่อน keyboard ของมือถือ
  SystemChannels.textInput.invokeMethod<void>('TextInput.hide');

  if (_showNumpad) {
    setState(() {
      _showNumpad = false;
    });
  }
}

void _finishAmountInput() {
  // เอา focus ออกจากช่องหมายเหตุและ TextField ทั้งหมด
  FocusScope.of(context).unfocus();

  // ซ่อน keyboard ของระบบ
  SystemChannels.textInput.invokeMethod<void>('TextInput.hide');

  // ปิดแป้นตัวเลข
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

  String _formatAmount(double v) {
    String s = v.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      s = s.replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  void _addOrUpdate() {
    final amount = double.tryParse(_amountText) ?? 0;

    final service = context.read<DataService>();
    if (amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(service.t('enter_amount'))));
      return;
    }
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(service.t('select_category'))));
      return;
    }

    setState(() {
      if (_editingId != null) {
        final index = _tempTransactions.indexWhere((t) => t['id'] == _editingId);
        if (index != -1) {
          _tempTransactions[index] = {
            'amount': amount,
            'category': _selectedCategory!,
            'note': _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
            'id': _editingId,
          };
        }
        _editingId = null;
      } else {
        _tempTransactions.add({
          'amount': amount,
          'category': _selectedCategory!,
          'note': _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
        });
      }
      _amountText = '';
      _noteCtrl.clear();
      _selectedCategory = null;
      // เพิ่ม/แก้ไขรายการเสร็จแล้ว พับแป้นตัวเลขลง รอจนกว่าจะเลือกหมวดหมู่ถัดไป
      _showNumpad = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _startEdit(Map<String, dynamic> tx) {
  // ป้องกัน keyboard ช่องหมายเหตุค้าง
  FocusScope.of(context).unfocus();

  SystemChannels.textInput.invokeMethod<void>('TextInput.hide');

  setState(() {
    _editingId = tx['id'] as String;
    _selectedCategory = tx['category'] as CategoryModel;
    _type = _selectedCategory!.type;
    _amountText = _formatAmount(tx['amount'] as double);
    _noteCtrl.text = (tx['note'] as String?) ?? '';

    // เปิด numpad เพื่อแก้จำนวนเงิน
    _showNumpad = true;
  });
}

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _selectedCategory = null;
      _amountText = '';
      _noteCtrl.clear();
      _showNumpad = false;
    });
  }

  void _removeTransaction(String id) {
    setState(() {
      _tempTransactions.removeWhere((t) => t['id'] == id);
      if (_editingId == id) {
        _editingId = null;
        _selectedCategory = null;
        _amountText = '';
        _noteCtrl.clear();
        _showNumpad = false;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final service = context.read<DataService>();
    if (_tempTransactions.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(service.t('add_at_least_one'))));
      return;
    }

    setState(() => _saving = true);

    try {
      for (final tx in _tempTransactions) {
        await service.addTransaction(
          type: tx['category'].type,
          amount: tx['amount'],
          category: tx['category'],
          date: DateTime.now(),
          note: tx['note'],
        );
      }

      if (!mounted) return;
      _tempTransactions.clear();
      _editingId = null;
      _selectedCategory = null;

      Navigator.pushReplacement(
          context, noAnimationRoute(const IncomeExpenseScreen()));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${service.t('save_failed')}: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final categories = service.categoriesByType(_type);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final panelHeight = _numpadHeight + bottomInset;

    return Scaffold(
      backgroundColor: AppColors.bg,
      // เปิดให้จอ resize หนี system keyboard (ตอนโฟกัสช่องหมายเหตุ)
      // เพื่อไม่ให้คีย์บอร์ดของเครื่องมาบังช่องหมายเหตุ
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ----- เนื้อหาหลักของหน้า -----
          Positioned.fill(
            child: Column(
              children: [
                AppHeader(
                  title: service.t('income_expense'),
                  onBack: () => Navigator.pushReplacement(
                      context, noAnimationRoute(const HomeScreen())),
                  trailing: Align(
                    alignment: Alignment.centerRight,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.savings_rounded, color: AppColors.accentDeep, size: 16),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      _typeToggle(),
                      const Spacer(),
                      GestureDetector(
                        onTap: (_saving || _tempTransactions.isEmpty) ? null : _save,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: _tempTransactions.isEmpty ? AppColors.textMuted : AppColors.accentPink,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(service.t('save'),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // พื้นที่หมวดหมู่/หมายเหตุ/รายการที่เพิ่ม ขยายเต็มพื้นที่ที่เหลือ
                // (ตอนนี้แป้นตัวเลขไม่ได้กินพื้นที่ตายตัวอีกต่อไป เพราะจะลอยขึ้นมาเฉพาะตอนใช้งาน)
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Text(service.t('categories'), style: AppTextStyles.heading),
                              const Spacer(),
                              Text(service.t('showing_categories'),
                                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accentBg,
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Text('${categories.length}',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.accentDeep)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _categoryRows(service, categories),
                        const SizedBox(height: 4),
                        Divider(height: 24, color: AppColors.border),
                        if (_tempTransactions.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '${service.t('items_added')}: ${_tempTransactions.length} ${service.t('items_unit')} ${service.t('tap_to_edit')}',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: _tempTransactions.map((tx) {
                                final isEditing = tx['id'] == _editingId;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: AppCard(
                                    color: isEditing ? AppColors.accentBg : null,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    onTap: () => _startEdit(tx),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: tx['category'].type == CategoryType.income
                                              ? AppColors.incomeBg
                                              : AppColors.expenseBg,
                                          child: CategoryIcon(category: tx['category'],
                                              size: 18,
                                              color: tx['category'].type == CategoryType.income
                                                  ? AppColors.income
                                                  : AppColors.expense),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(service.categoryName(tx['category']),
                                                  style: TextStyle(
                                                      fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                                              if (tx['note'] != null)
                                                Text(tx['note'],
                                                    style: TextStyle(
                                                        color: AppColors.textSecondary, fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                        Text('${_formatAmount(tx['amount'] as double)}฿',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _removeTransaction(tx['id']),
                                          child: Icon(Icons.close_rounded,
                                              size: 20, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _editingId != null
                            ? Row(
                                children: [
                                  Icon(Icons.edit_rounded, size: 16, color: AppColors.ink),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${service.t('editing')}: ${_selectedCategory != null ? service.categoryName(_selectedCategory!) : ''}',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.ink),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _cancelEdit,
                                    style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                    child: Text(service.t('cancel_edit'), style: const TextStyle(fontSize: 12)),
                                  ),
                                ],
                              )
                            : Text(
                                _selectedCategory != null
                                    ? '${service.t('selected_category')}: ${service.categoryName(_selectedCategory!)}'
                                    : service.t('select_category_prompt'),
                                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _addOrUpdate,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.accentPink,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Icon(_editingId != null ? Icons.check_rounded : Icons.add,
                              color: Colors.white, size: 28),
                        ),
                      ),
                    ],
                  ),
                ),
                // ช่องหมายเหตุ: ย้ายมาไว้ใกล้ปุ่ม + ด้านล่าง และจะ "เลื่อนขึ้น/หายไป"
                // เฉพาะตอนแป้นตัวเลขเปิดอยู่ กันไม่ให้แป้นเลื่อนขึ้นมาบัง
                ClipRect(
                  child: AnimatedAlign(
                    duration: _numpadAnim,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.bottomCenter,
                    heightFactor: _showNumpad ? 0 : 1,
                    child: AnimatedOpacity(
                      duration: _numpadAnim,
                      opacity: _showNumpad ? 0 : 1,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: AppTextField(
                          controller: _noteCtrl,
                          hint: service.t('note_optional'),
                          icon: Icons.edit_note_rounded,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // แถบจำนวนเงิน: แตะเพื่อเปิดแป้นตัวเลข พร้อมเคอร์เซอร์กระพริบระหว่างพิมพ์
                _amountDisplay(),
                // จองพื้นที่ด้านล่างเท่ากับความสูงแป้นตัวเลข เมื่อแป้นถูกเปิดอยู่
                // เพื่อดันเนื้อหาขึ้น ไม่ให้แป้นที่ลอยขึ้นมาบังจำนวนเงิน/ปุ่มเพิ่มรายการ
                AnimatedContainer(
                  duration: _numpadAnim,
                  curve: Curves.easeOutCubic,
                  height: _showNumpad ? panelHeight : bottomInset + 8,
                ),
              ],
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
      bottomNavigationBar: const BottomNav(currentIndex: 2),
    );
  }

  // กล่องแสดง/กรอกจำนวนเงิน: มีกรอบสีเดียวกับช่องหมายเหตุ, มีลายน้ำตอนยังไม่กรอก,
  // และเคอร์เซอร์กระพริบอยู่ "หน้า" สัญลักษณ์ ฿ ระหว่างที่กำลังพิมพ์
  Widget _amountDisplay() {
  final showPlaceholder = !_showNumpad && _amountText.isEmpty;

  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: _openNumpad,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: _showNumpad
              ? AppColors.accentPink
              : AppColors.border,
          width: _showNumpad ? 1.4 : 1,
        ),
      ),
      child: showPlaceholder
          ? Align(
              alignment: Alignment.centerRight,
              child: Text(
                'กรุณาระบุจำนวนเงิน',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ==========================================
                // กลุ่ม "จำนวนเงิน + cursor + ฿"
                // ==========================================
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // จำนวนเงิน
                    Text(
                      _amountText,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    // Cursor
                    if (_showNumpad) ...[
                      const SizedBox(width: 3),

                      _BlinkingCursor(
                        color: AppColors.accentPink,
                        height: 22,
                      ),

                      const SizedBox(width: 3),
                    ],

                    // ฿ แสดง "เพียงครั้งเดียว"
                    Text(
                      '฿',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),

                // ==========================================
                // ปุ่ม ✓
                // ==========================================
                if (_showNumpad) ...[
                  const SizedBox(width: 10),

                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _finishAmountInput,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.accentDeep,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 23,
                      ),
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

  // จัดหมวดหมู่เป็น Grid 4 ไอคอนต่อแถว อยู่ในกรอบสูงคงที่ที่เลื่อนขึ้น-ลงได้ในตัวเอง
  // (แทนที่จะปล่อยให้ grid ขยายความสูงตามจำนวนหมวดหมู่ ซึ่งจะไปเบียดพื้นที่ของ
  // ช่องหมายเหตุ/ปุ่มเพิ่มรายการ/เครื่องคิดเลขด้านล่างจนดูอัดแน่นเกินไป)
  Widget _categoryRows(DataService service, List<CategoryModel> categories) {
    final tiles = <Widget>[
      ...categories.asMap().entries.map((e) => _categoryTile(e.value, service, e.key)),
      _otherCategoryTile(service),
    ];

    return SizedBox(
      height: 216,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const ClampingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 4,
          childAspectRatio: 0.82,
        ),
        itemCount: tiles.length,
        itemBuilder: (context, i) => tiles[i],
      ),
    );
  }

  Widget _categoryTile(CategoryModel c, DataService service, int index) {
    final selected = _selectedCategory?.id == c.id;
    final tint = _categoryTint[index % _categoryTint.length];
    final tintIcon = _categoryTintIcon[index % _categoryTintIcon.length];
    return GestureDetector(
      onTap: () {
  // ถ้าก่อนหน้านี้กำลังพิมพ์หมายเหตุ
  // ต้องเอา focus ออกจากช่องหมายเหตุก่อน
  FocusScope.of(context).unfocus();

  SystemChannels.textInput.invokeMethod<void>('TextInput.hide');

  setState(() {
    _selectedCategory = c;

    // เลือกหมวดหมู่แล้วเปิด numpad
    _showNumpad = true;
  });
},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ขยายจาก radius 26 / icon 24 เดิมพอประมาณ (~15-20%) ให้ชัดขึ้นแต่ไม่ใหญ่จนเกะกะ
          CircleAvatar(
            radius: 30,
            backgroundColor: selected ? AppColors.accentDeep : tint,
            child: CategoryIcon(category: c, color: selected ? Colors.white : tintIcon, size: 25),
          ),
          const SizedBox(height: 6),
          Text(
            service.categoryName(c),
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _otherCategoryTile(DataService service) {
    return GestureDetector(
      onTap: () => _showAddCategoryDialog(service),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.surface,
            child: Icon(Icons.add_rounded, color: AppColors.textSecondary, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            service.t('other_category'),
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCategoryDialog(DataService service) async {
    // ปิดแป้นตัวเลขไว้ก่อนระหว่างเปิด dialog เพิ่มหมวดหมู่ กันบดบัง/ซ้อนทับกัน
    _closeNumpad();
    final nameCtrl = TextEditingController();
    IconData selectedIcon = _customCategoryIcons.first;

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (dialogContext) {
        bool saving = false;
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> confirm() async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                setDialogState(() => errorText = service.t('please_enter_category_name'));
                return;
              }
              setDialogState(() {
                saving = true;
                errorText = null;
              });
              final created = await service.addCategory(name, _type, selectedIcon);
              if (!mounted) return;
              setState(() {
                _selectedCategory = created;
                _showNumpad = true;
              });
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
                          child: Icon(selectedIcon, color: AppColors.ink, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(service.t('add_custom_category_title'),
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
                    AppTextField(
                      controller: nameCtrl,
                      hint: service.t('category_name_hint'),
                      icon: Icons.label_outline_rounded,
                      autofocus: true,
                      errorText: errorText,
                      onChanged: (_) {
                        if (errorText != null) setDialogState(() => errorText = null);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(service.t('choose_icon'),
                        style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 140,
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: _customCategoryIcons.length,
                        itemBuilder: (context, i) {
                          final icon = _customCategoryIcons[i];
                          final selected = icon == selectedIcon;
                          return GestureDetector(
                            onTap: () => setDialogState(() => selectedIcon = icon),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: selected ? AppColors.accentDeep : AppColors.surface,
                              child: Icon(icon,
                                  size: 20, color: selected ? Colors.white : AppColors.textSecondary),
                            ),
                          );
                        },
                      ),
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
                            onPressed: saving ? null : confirm,
                            child: saving
                                ? SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: AppColors.inkOn))
                                : Text(service.t('add'),
                                    style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.inkOn)),
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

  Widget _typeToggle() {
    final service = context.watch<DataService>();
    final isIncome = _type == CategoryType.income;
    const toggleWidth = 176.0;
    const toggleHeight = 36.0;
    return Container(
      width: toggleWidth,
      height: toggleHeight,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: isIncome ? Alignment.centerLeft : Alignment.centerRight,
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
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() {
                    _type = CategoryType.income;
                    if (_editingId == null) _selectedCategory = null;
                  }),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CuteMascot(
                            kind: CuteMascotKind.income,
                            color: isIncome ? Colors.white : AppColors.income,
                            size: 14),
                        const SizedBox(width: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: isIncome ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                          child: Text(service.t('incomes_tab')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() {
                    _type = CategoryType.expense;
                    if (_editingId == null) _selectedCategory = null;
                  }),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CuteMascot(
                            kind: CuteMascotKind.expense,
                            color: !isIncome ? Colors.white : AppColors.expense,
                            size: 14),
                        const SizedBox(width: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: !isIncome ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                          child: Text(service.t('expenses_tab')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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

  // สีคีย์แบบพาสเทลหลากสีตามดีไซน์อ้างอิง (X ชมพู, ⌫ ฟ้า, . เหลือง, ตัวเลขขาว)
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
class _BlinkingCursor extends StatefulWidget {
  final Color color;
  final double height;
  const _BlinkingCursor({required this.color, required this.height});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
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