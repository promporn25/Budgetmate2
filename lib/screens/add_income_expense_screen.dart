import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

/// หน้า Add Income/Expense (3.4.10)
class AddIncomeExpenseScreen extends StatefulWidget {
  const AddIncomeExpenseScreen({super.key});

  @override
  State<AddIncomeExpenseScreen> createState() => _AddIncomeExpenseScreenState();
}

class _AddIncomeExpenseScreenState extends State<AddIncomeExpenseScreen> {
  CategoryType _type = CategoryType.income;
  CategoryModel? _selectedCategory;
  String _amountText = '';
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  String? _editingId;
  List<Map<String, dynamic>> _tempTransactions = [];
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    _noteCtrl.dispose();
    super.dispose();
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
    setState(() {
      _editingId = tx['id'] as String;
      _selectedCategory = tx['category'] as CategoryModel;
      _type = _selectedCategory!.type;
      _amountText = _formatAmount(tx['amount'] as double);
      _noteCtrl.text = (tx['note'] as String?) ?? '';
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _selectedCategory = null;
      _amountText = '';
      _noteCtrl.clear();
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
      await service.addTransactionsBatch(_tempTransactions
          .map((tx) => (
                type: (tx['category'] as CategoryModel).type,
                amount: tx['amount'] as double,
                category: tx['category'] as CategoryModel,
                note: tx['note'] as String?,
              ))
          .toList());

      if (!mounted) return;
      _tempTransactions.clear();
      _editingId = null;
      _selectedCategory = null;

      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const IncomeExpenseScreen()));
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

    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: service.t('back_home'),
          onPressed: () => Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const HomeScreen())),
        ),
        title: Text(service.t('income_expense'),
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ),
      body: Column(
        children: [
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
                      color: _tempTransactions.isEmpty ? AppColors.textMuted : AppColors.accentDeep,
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
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(service.t('categories'), style: AppTextStyles.heading),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: _type == CategoryType.expense ? 184 : 92,
                    child: _categoryRows(service, categories),
                  ),
                  Divider(height: 24, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AppTextField(
                      controller: _noteCtrl,
                      hint: service.t('note_optional'),
                      icon: Icons.edit_note_rounded,
                    ),
                  ),
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
                                    child: Icon(tx['category'].icon,
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
                                  Text('฿${(tx['amount'] as double).toStringAsFixed(2)}',
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
                      color: AppColors.accentDeep,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Icon(_editingId != null ? Icons.check_rounded : Icons.add,
                        color: Colors.white, size: 28),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('฿ $_amountText',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(flex: 2, child: _numPad()),
          const SizedBox(height: 8),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 2),
    );
  }

  Widget _categoryRows(DataService service, List<CategoryModel> categories) {
    final tiles = <Widget>[
      ...categories.map((c) => _categoryTile(c, service)),
      _otherCategoryTile(service),
    ];

    if (_type != CategoryType.expense) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: tiles.map((t) => _tileSlot(t)).toList(),
        ),
      );
    }

    final columns = <Widget>[];
    for (int i = 0; i < tiles.length; i += 2) {
      final top = tiles[i];
      final bottom = i + 1 < tiles.length ? tiles[i + 1] : null;
      columns.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _tileSlot(top),
            const SizedBox(height: 4),
            bottom != null ? _tileSlot(bottom) : const SizedBox(width: 78, height: 82),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: columns,
      ),
    );
  }

  Widget _tileSlot(Widget tile) {
    return SizedBox(width: 78, height: 82, child: Center(child: tile));
  }

  Widget _categoryTile(CategoryModel c, DataService service) {
    final selected = _selectedCategory?.id == c.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = c),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: selected ? AppColors.accentDeep : AppColors.surface,
            child: Icon(c.icon, color: selected ? Colors.white : AppColors.textSecondary, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            service.categoryName(c),
            style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
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
            radius: 26,
            backgroundColor: AppColors.surface,
            child: Icon(Icons.add_rounded, color: AppColors.textSecondary, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            service.t('other_category'),
            style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCategoryDialog(DataService service) async {
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
              setState(() => _selectedCategory = created);
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
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: isIncome ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                      child: Text(service.t('incomes_tab')),
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
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: !isIncome ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                      child: Text(service.t('expenses_tab')),
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
                                padding: const EdgeInsets.all(6),
                                child: Material(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                    onTap: () => key == '⌫' ? _backspace() : _pressDigit(key),
                                    child: Center(
                                      child: Text(key,
                                          style: TextStyle(
                                              fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
}