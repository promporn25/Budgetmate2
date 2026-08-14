import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/period_selector.dart';

const List<String> _thaiMonthsShort = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
];
const List<String> _enMonthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// หน้า Statistic (3.4.8) - วิเคราะห์แนวโน้มรายรับ/รายจ่าย และความคืบหน้าการออม
class StatisticScreen extends StatefulWidget {
  const StatisticScreen({super.key});

  @override
  State<StatisticScreen> createState() => _StatisticScreenState();
}

class _StatisticScreenState extends State<StatisticScreen> {
  ChartPeriod _period = ChartPeriod.month;
  DateTime _anchor = DateTime.now();

  List<MapEntry<String, Map<String, double>>> _series(DataService service) {
    final isThai = service.currentLanguage != 'English';
    switch (_period) {
      case ChartPeriod.day:
        final data = service.dailySummary(days: 7, endDate: _anchor);
        return data.map((e) => MapEntry('${e.key.day}/${e.key.month}', e.value)).toList();
      case ChartPeriod.month:
        final data = service.monthlySummary(months: 6, endMonth: _anchor);
        final months = isThai ? _thaiMonthsShort : _enMonthsShort;
        return data.map((e) => MapEntry(months[e.key.month - 1], e.value)).toList();
      case ChartPeriod.year:
        final data = service.yearlySummary(years: 5, endYear: _anchor.year);
        return data.map((e) => MapEntry('${e.key}', e.value)).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final series = _series(service);
    final mostSpent = service.mostSpentCategory;
    final pct = service.incomeExpensePercentage;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(service.t('statistic_title'),
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(service.t('income_expense'), style: AppTextStyles.heading),
            const SizedBox(height: 12),
            PeriodFilterBar(
              period: _period,
              anchor: _anchor,
              onPeriodChanged: (p) => setState(() => _period = p),
              onAnchorChanged: (d) => setState(() => _anchor = d),
            ),
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
              child: Column(
                children: [
                  SizedBox(
                    height: 180,
                    child: LineChart(
                      LineChartData(
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
                        lineBarsData: [
                          LineChartBarData(
                            isCurved: true,
                            color: AppColors.accent,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            spots: List.generate(series.length,
                                (i) => FlSpot(i.toDouble(), series[i].value['income'] ?? 0)),
                          ),
                          LineChartBarData(
                            isCurved: true,
                            color: AppColors.accentDeep,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            spots: List.generate(series.length,
                                (i) => FlSpot(i.toDouble(), series[i].value['expense'] ?? 0)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _legendDot(AppColors.accent, '${service.t('income')} ${pct['income']!.toStringAsFixed(0)}%'),
                      const SizedBox(width: 16),
                      _legendDot(AppColors.accentDeep, '${service.t('expense')} ${pct['expense']!.toStringAsFixed(0)}%'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (mostSpent != null)
              AppCard(
                color: AppColors.accentAltBg,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(mostSpent.key.icon, color: AppColors.accentDeep),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(service.t('most_spent_category'),
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(service.categoryName(mostSpent.key),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                    Text('฿${mostSpent.value.toStringAsFixed(0)}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            const SizedBox(height: 28),
            Text(service.t('goal_saving'), style: AppTextStyles.heading),
            const SizedBox(height: 12),
            if (service.goals.isEmpty)
              EmptyState(icon: Icons.savings_outlined, text: service.t('no_goals'))
            else
              ...service.goals.map((g) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.bg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(g.icon, color: AppColors.accentDeep, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(g.name,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              ),
                              Text('${(g.progress * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: g.progress,
                              minHeight: 9,
                              backgroundColor: AppColors.border,
                              color: g.progress >= 1 ? AppColors.success : AppColors.accentDeep,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                              '฿${g.savedAmount.toStringAsFixed(0)} / ฿${g.targetAmount.toStringAsFixed(0)}',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          if (g.isNearTarget)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(service.t('near_target'),
                                  style: TextStyle(color: AppColors.ink, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                  )),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 3),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
      ],
    );
  }
}