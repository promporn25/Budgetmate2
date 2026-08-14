import 'package:budgetmate/screens/app_theme.dart';
import 'package:budgetmate/screens/goal_saving_screen.dart';
import 'package:budgetmate/screens/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/period_selector.dart';
import 'history_screen.dart';

const List<String> _thaiMonthsShort = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
];
const List<String> _enMonthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// หน้า Home (3.4.6) - แสดงภาพรวมทางการเงินของผู้ใช้งาน
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ChartPeriod _period = ChartPeriod.month;
  DateTime _anchor = DateTime.now();

  List<MapEntry<String, double>> _expenseSeries(DataService service) {
    final isThai = service.currentLanguage != 'English';
    switch (_period) {
      case ChartPeriod.day:
        final data = service.dailySummary(days: 7, endDate: _anchor);
        return data
            .map((e) => MapEntry('${e.key.day}/${e.key.month}', e.value['expense'] ?? 0))
            .toList();
      case ChartPeriod.month:
        final data = service.monthlySummary(months: 6, endMonth: _anchor);
        final months = isThai ? _thaiMonthsShort : _enMonthsShort;
        return data
            .map((e) => MapEntry(months[e.key.month - 1], e.value['expense'] ?? 0))
            .toList();
      case ChartPeriod.year:
        final data = service.yearlySummary(years: 5, endYear: _anchor.year);
        return data.map((e) => MapEntry('${e.key}', e.value['expense'] ?? 0)).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final series = _expenseSeries(service);
    final maxVal = series.map((e) => e.value).fold<double>(0, (a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(
            '${service.t('greeting')}, ${service.currentUser?.name ?? service.t('default_user')}',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: Icon(Icons.history_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 28),
            Text(service.t('expense_trend'), style: AppTextStyles.heading),
            const SizedBox(height: 12),
            PeriodFilterBar(
              period: _period,
              anchor: _anchor,
              onPeriodChanged: (p) => setState(() => _period = p),
              onAnchorChanged: (d) => setState(() => _anchor = d),
            ),
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.fromLTRB(12, 20, 16, 8),
              child: SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    maxY: maxVal == 0 ? 100 : maxVal * 1.2,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= series.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(series[idx].key,
                                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: List.generate(series.length, (i) {
                      return BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: series[i].value,
                          color: AppColors.accentDeep,
                          width: 18,
                          borderRadius: BorderRadius.circular(6),
                        )
                      ]);
                    }),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ===== ปุ่มกระเป๋าตัง / กระปุกออมสิน =====
            Row(
  children: [
    Expanded(
      child: _ActionButton(
        icon: Icons.account_balance_wallet_rounded,
        label: service.t('Wallet'),
        color: AppColors.accentDeep,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WalletScreen()),
        ),
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: _ActionButton(
        icon: Icons.savings_rounded,
        label: service.t('GoalSaving'),
        color: AppColors.accentDeep,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GoalSavingScreen()),
        ),
      ),
    ),
  ],
),
            const SizedBox(height: 28),

            Text(service.t('exchange_rate'), style: AppTextStyles.heading),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _RateRow(buyLabel: service.t('buy'), sellLabel: service.t('sell'),
                      flag: '🇺🇸', code: 'USD', buy: '31.55', sell: '31.75'),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }

  Widget _summaryCard(String title, double value, Color bg, Color fg, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
              Text(title, style: TextStyle(color: fg, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 8),
          Text('฿${value.toStringAsFixed(2)}',
              style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  final String flag, code, buy, sell, buyLabel, sellLabel;
  const _RateRow({
    required this.flag,
    required this.code,
    required this.buy,
    required this.sell,
    required this.buyLabel,
    required this.sellLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(code, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const Spacer(),
          Text('$buyLabel $buy', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
          const SizedBox(width: 12),
          Text('$sellLabel $sell', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: AppCard(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}