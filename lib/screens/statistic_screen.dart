import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/category_model.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/period_selector.dart';
import 'home_screen.dart';

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

  dynamic _topGoal(DataService service) {
    if (service.goals.isEmpty) return null;
    final sorted = [...service.goals]..sort((a, b) => b.progress.compareTo(a.progress));
    return sorted.first;
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final series = _series(service);
    final mostSpent = service.mostSpentCategory;
    final pct = service.incomeExpensePercentage;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: service.t('statistic_title'),
            onBack: () => Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const HomeScreen(),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            ),
          ),
          Expanded(
            // ห่อด้วย RefreshIndicator กันไม่ให้ดึงหน้าจอเกินขอบบนแล้วเห็นพื้นที่ว่างสีขาว
            child: RefreshIndicator(
              color: AppColors.accentDeep,
              backgroundColor: AppColors.card,
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                            color: AppColors.accentDeep,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            spots: List.generate(series.length,
                                (i) => FlSpot(i.toDouble(), series[i].value['income'] ?? 0)),
                          ),
                          LineChartBarData(
                            isCurved: true,
                            color: AppColors.accentPink,
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
                      _legendDot(AppColors.income,
                          '${service.t('income')} ${pct['income']!.toStringAsFixed(0)}%', true),
                      const SizedBox(width: 16),
                      _legendDot(AppColors.expense,
                          '${service.t('expense')} ${pct['expense']!.toStringAsFixed(0)}%', false),
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
                      child: CategoryIcon(category: mostSpent.key, color: AppColors.accentDeep),
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
            if (service.goals.isNotEmpty) _FeaturedGoalCard(goal: _topGoal(service)!, service: service),
            if (service.goals.isNotEmpty) const SizedBox(height: 16),
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CuteMascot(kind: CuteMascotKind.bell, color: AppColors.ink, size: 16),
                                  const SizedBox(width: 4),
                                  Text(service.t('near_target'),
                                      style: TextStyle(color: AppColors.ink, fontSize: 12)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  )),
            const SizedBox(height: 80),
                ],
              ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 3),
    );
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() {});
  }

  Widget _legendDot(Color color, String label, bool isIncome) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CuteMascot(
            kind: isIncome ? CuteMascotKind.income : CuteMascotKind.expense, color: color, size: 14),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
      ],
    );
  }
}

/// การ์ดไฮไลต์เป้าหมายที่คืบหน้ามากที่สุด (โทนมินต์) แทนที่จะแสดงแค่ในลิสต์ปกติ
/// ให้ผู้ใช้เห็นเป้าหมายที่ใกล้สำเร็จที่สุดเด่นชัดตั้งแต่แรก ตามดีไซน์อ้างอิง
class _FeaturedGoalCard extends StatelessWidget {
  final dynamic goal; // GoalModel
  final DataService service;
  const _FeaturedGoalCard({required this.goal, required this.service});

  @override
  Widget build(BuildContext context) {
    final pct = (goal.progress * 100).clamp(0, 100).toStringAsFixed(0);
    final near = goal.isNearTarget as bool;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Stack(
        children: [
          // มาสคอตตกแต่งมุมขวา (placeholder จนกว่าจะมี asset จริง) ไม่บังข้อความ/progress bar
          Positioned(
            right: 0,
            top: 4,
            child: Opacity(
              opacity: 0.9,
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.favorite_rounded, color: AppColors.accentPink, size: 22),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 46),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Goal Progress',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                    const SizedBox(width: 6),
                    const Text('🌸', style: TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  near ? service.t('near_target') : goal.name,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          value: goal.progress,
                          minHeight: 10,
                          backgroundColor: Colors.white,
                          color: AppColors.accentDeep,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('$pct%',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}