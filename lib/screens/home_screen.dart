import 'package:budgetmate/screens/app_theme.dart';
import 'package:budgetmate/screens/goal_saving_screen.dart';
import 'package:budgetmate/screens/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
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
/// ดีไซน์ v3 "Sky Fintech": ส่วนหัวไล่เฉดฟ้าพาสเทลโค้งมน + Avatar/กระดิ่งแจ้งเตือน
/// และเพิ่มส่วน "Pinned Goals" แสดงเป้าหมายการออมล่าสุดแบบการ์ดสีพาสเทล
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
      extendBodyBehindAppBar: true,
      // ห่อด้วย RefreshIndicator เพื่อให้ตอนดึงหน้าจอเกินขอบบน (overscroll) แสดงไอคอน
      // "กำลังโหลด" แบบมีความหมายแทนที่จะเห็นพื้นที่ว่างสีขาวโล่งๆ เหมือนก่อนหน้านี้
      body: RefreshIndicator(
        color: AppColors.accentDeep,
        backgroundColor: AppColors.card,
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
        // ต้องใช้ AlwaysScrollableScrollPhysics ไม่งั้นถ้าเนื้อหาสั้นกว่าจอ
        // จะดึงเพื่อรีเฟรชไม่ได้เลย
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkyHeader(service: service),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      height: 190,
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
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [AppColors.accentDeep, AppColors.accent],
                                ),
                                width: 14,
                                borderRadius: BorderRadius.circular(6),
                              )
                            ]);
                          }),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ===== ปุ่มกระเป๋าตัง / กระปุกออมสิน =====
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.account_balance_wallet_rounded,
                          label: service.t('wallet_title'),
                          iconBg: AppColors.accentDeep,
                          cardBg: AppColors.accentBg,
                          onTap: () => Navigator.push(
                            context,
                            noAnimationRoute(const WalletScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.savings_rounded,
                          label: service.t('goal_saving'),
                          iconBg: AppColors.accentPink,
                          cardBg: AppColors.accentAltBg,
                          onTap: () => Navigator.push(
                            context,
                            noAnimationRoute(const GoalSavingScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(service.t('exchange_rate'), style: AppTextStyles.heading),
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _RateRow(buyLabel: service.t('buy'), sellLabel: service.t('sell'),
                            flag: const Text('🇺🇸', style: TextStyle(fontSize: 22)),
                            code: 'USD', buy: '31.55', sell: '31.75'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (service.goals.isNotEmpty) ...[
                    Row(
                      children: [
                        Text('Pinned Goals', style: AppTextStyles.heading),
                        const SizedBox(width: 6),
                        Icon(Icons.push_pin_rounded, size: 15, color: AppColors.accentPink),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: List.generate(
                        service.goals.length > 2 ? 2 : service.goals.length,
                        (i) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: i == 0 && service.goals.length > 1 ? 12 : 0),
                            child: _PinnedGoalCard(
                              goal: service.goals[i],
                              bg: AppColors.pinnedGoalBg[i % AppColors.pinnedGoalBg.length],
                              onTap: () => Navigator.push(context,
                                  noAnimationRoute(const GoalSavingScreen())),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 70),
          ],
        ),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }

  // จำลองการรีเฟรชข้อมูล (ข้อมูลจริงมาจาก Provider<DataService> ซึ่งอัปเดต
  // อัตโนมัติอยู่แล้วเมื่อมีการเปลี่ยนแปลง ฟังก์ชันนี้แค่ทำให้มีจังหวะหน่วง
  // สั้นๆ ให้ผู้ใช้เห็นวงกลมโหลดก่อนพับกลับ)
  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() {});
  }
}

/// ส่วนหัวไล่เฉดฟ้าพาสเทลโค้งมนด้านล่าง: รูปโปรไฟล์ + คำทักทาย + กระดิ่งแจ้งเตือน (ไปหน้า History)
class _SkyHeader extends StatelessWidget {
  final DataService service;
  const _SkyHeader({required this.service});

  @override
  Widget build(BuildContext context) {
    final avatarPath = service.avatarPath;
    final hasImage = avatarPath != null && File(avatarPath).existsSync();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.accentDeep.withOpacity(0.9), AppColors.accent, AppColors.bg],
          stops: const [0, 0.55, 1],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ประกายดาวเล็กๆ ตกแต่งมุมบน ให้ดูสดใสมีชีวิตชีวาแบบภาพอ้างอิง
          Positioned(
            right: 70,
            top: 2,
            child: Icon(Icons.auto_awesome_rounded,
                size: 16, color: Colors.white.withOpacity(0.85)),
          ),
          Positioned(
            right: 96,
            top: 22,
            child: Icon(Icons.auto_awesome_rounded,
                size: 9, color: Colors.white.withOpacity(0.6)),
          ),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
                backgroundImage: hasImage ? FileImage(File(avatarPath)) : null,
                child: hasImage ? null : Icon(Icons.person, color: AppColors.accentDeep, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${service.t('greeting')}, ${service.currentUser?.name ?? service.t('default_user')} 👋',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 17, color: Color(0xFF3D568F)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                    context, noAnimationRoute(const HistoryScreen())),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(Icons.notifications_rounded, color: AppColors.accentDeep, size: 21),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  final Widget flag;
  final String code, buy, sell, buyLabel, sellLabel;
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
          flag,
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
  final Color iconBg;
  final Color cardBg;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.iconBg,
    required this.cardBg,
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
          color: cardBg,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          child: Row(
            children: [
              Icon(icon, size: 26, color: iconBg),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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

/// การ์ดเป้าหมายการออมแบบพาสเทล ใช้กับส่วน "Pinned Goals" ในหน้า Home
class _PinnedGoalCard extends StatelessWidget {
  final dynamic goal; // GoalModel
  final Color bg;
  final VoidCallback onTap;
  const _PinnedGoalCard({required this.goal, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final bool near = goal.isNearTarget as bool;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(goal.icon, size: 16, color: AppColors.pinnedGoalIcon),
                ),
                const Spacer(),
                if (near)
                  Icon(Icons.star_rounded, size: 18, color: Colors.white.withOpacity(0.9)),
              ],
            ),
            const SizedBox(height: 10),
            Text(goal.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF3D568F)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(fmt.format(goal.targetAmount),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF6E7FA3))),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: goal.progress as double,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.6),
                color: AppColors.accentDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}