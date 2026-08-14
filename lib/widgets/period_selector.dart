import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';

/// ประเภทช่วงเวลาที่ใช้กรองกราฟรายรับ-รายจ่าย: วัน / เดือน / ปี
enum ChartPeriod { day, month, year }

const List<String> _thaiMonthsFull = [
  'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];
const List<String> _enMonthsFull = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// แถบเลือกช่วงเวลา (วัน/เดือน/ปี) พร้อมปุ่มเลือกวันที่/เดือน/ปีที่ต้องการดูข้อมูลจริง
class PeriodFilterBar extends StatelessWidget {
  final ChartPeriod period;
  final DateTime anchor;
  final ValueChanged<ChartPeriod> onPeriodChanged;
  final ValueChanged<DateTime> onAnchorChanged;

  const PeriodFilterBar({
    super.key,
    required this.period,
    required this.anchor,
    required this.onPeriodChanged,
    required this.onAnchorChanged,
  });

  Future<void> _pickDay(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: anchor,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme(
              brightness: AppColors.brightness,
              primary: AppColors.accentDeep,
              onPrimary: Colors.white,
              secondary: AppColors.accent,
              onSecondary: AppColors.textPrimary,
              error: AppColors.danger,
              onError: Colors.white,
              surface: AppColors.bg,
              onSurface: AppColors.textPrimary,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.ink,
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: AppColors.bg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) onAnchorChanged(picked);
  }

  Future<void> _pickMonth(BuildContext context, bool isThai) async {
    int year = anchor.year;
    final months = isThai ? _thaiMonthsFull : _enMonthsFull;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left_rounded, color: AppColors.textPrimary),
                          onPressed: () => setSheetState(() => year--),
                        ),
                        Expanded(
                          child: Text('$year',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right_rounded, color: AppColors.textPrimary),
                          onPressed: year >= DateTime.now().year
                              ? null
                              : () => setSheetState(() => year++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.2,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, i) {
                        final m = i + 1;
                        final disabled = DateTime(year, m, 1).isAfter(DateTime.now());
                        final selected = m == anchor.month && year == anchor.year;
                        return Material(
                          color: selected ? AppColors.accentDeep : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            onTap: disabled
                                ? null
                                : () {
                                    onAnchorChanged(DateTime(year, m, 1));
                                    Navigator.pop(sheetContext);
                                  },
                            child: Center(
                              child: Text(months[i],
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: disabled
                                          ? AppColors.textMuted
                                          : selected
                                              ? Colors.white
                                              : AppColors.textPrimary)),
                            ),
                          ),
                        );
                      },
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

  Future<void> _pickYear(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(
              height: 280,
              child: ListView.builder(
                itemCount: 30,
                itemBuilder: (context, i) {
                  final y = DateTime.now().year - i;
                  final selected = y == anchor.year;
                  return ListTile(
                    title: Text('$y', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textPrimary)),
                    tileColor: selected ? AppColors.accentBg : null,
                    onTap: () {
                      onAnchorChanged(DateTime(y, anchor.month, 1));
                      Navigator.pop(sheetContext);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  String _label(DataService service) {
    final isThai = service.currentLanguage != 'English';
    final months = isThai ? _thaiMonthsFull : _enMonthsFull;
    switch (period) {
      case ChartPeriod.day:
        return '${anchor.day} ${months[anchor.month - 1]} ${anchor.year}';
      case ChartPeriod.month:
        return '${months[anchor.month - 1]} ${anchor.year}';
      case ChartPeriod.year:
        return '${anchor.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final isThai = service.currentLanguage != 'English';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _periodChip(service.t('period_day'), ChartPeriod.day),
            const SizedBox(width: 8),
            _periodChip(service.t('period_month'), ChartPeriod.month),
            const SizedBox(width: 8),
            _periodChip(service.t('period_year'), ChartPeriod.year),
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () {
            switch (period) {
              case ChartPeriod.day:
                _pickDay(context);
                break;
              case ChartPeriod.month:
                _pickMonth(context, isThai);
                break;
              case ChartPeriod.year:
                _pickYear(context);
                break;
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(_label(service),
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: AppColors.textPrimary)),
                const SizedBox(width: 6),
                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _periodChip(String label, ChartPeriod value) {
    final selected = period == value;
    return GestureDetector(
      onTap: () => onPeriodChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentDeep : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12.5)),
      ),
    );
  }
}