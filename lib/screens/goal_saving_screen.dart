import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/goal_model.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import 'add_goal_saving_screen.dart';

/// หน้า Goal Saving (3.4.11) - กำหนดและติดตามเป้าหมายการออมเงิน
class GoalSavingScreen extends StatelessWidget {
  const GoalSavingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(service.t('goal_saving'),
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.account_balance_wallet_rounded,
                          color: AppColors.ink, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(service.t('ledger_balance'),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 10),
                Text('฿${service.balance.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (service.goals.isEmpty)
            EmptyState(icon: Icons.savings_outlined, text: service.t('no_goals'))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              itemCount: service.goals.length,
              itemBuilder: (context, i) {
                final g = service.goals[i];
                return Dismissible(
                  key: ValueKey(g.id),
                  onDismissed: (_) async => service.deleteGoal(g.id),
                  background: Container(
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  ),
                  child: GestureDetector(
                    onTap: () => _showDepositDialog(context, g),
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.bg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(g.icon, color: AppColors.accentDeep, size: 18),
                              ),
                              const Spacer(),
                              if (g.status == GoalStatus.completed)
                                Icon(Icons.check_circle_rounded,
                                    color: AppColors.success, size: 18)
                              else
                                Icon(Icons.add_circle_outline_rounded,
                                    color: AppColors.accentDeep, size: 18),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(g.name,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const Spacer(),
                          Text('฿${g.savedAmount.toStringAsFixed(0)} / ฿${g.targetAmount.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: g.progress,
                              minHeight: 7,
                              backgroundColor: AppColors.border,
                              color: g.progress >= 1 ? AppColors.success : AppColors.accentDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accentDeep,
        elevation: 0,
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddGoalSavingScreen())),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }
}

/// เปิด dialog ให้ผู้ใช้กรอกจำนวนเงินที่ต้องการ "โอนเงินจริง" เข้าเป้าหมาย [goal]
Future<void> _showDepositDialog(BuildContext context, GoalModel goal) async {
  final service = context.read<DataService>();
  final controller = TextEditingController();
  final remaining = (goal.targetAmount - goal.savedAmount).clamp(0, goal.targetAmount).toDouble();
  final maxTransferable = remaining < service.balance ? remaining : service.balance;

  await showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (dialogContext) {
      bool submitting = false;
      String? errorText;
      return StatefulBuilder(
        builder: (context, setState) {
          void applyQuickAmount(double value) {
            if (value <= 0) return;
            controller.text = value == value.roundToDouble()
                ? value.toStringAsFixed(0)
                : value.toStringAsFixed(2);
            controller.selection =
                TextSelection.collapsed(offset: controller.text.length);
            setState(() => errorText = null);
          }

          Future<void> submit() async {
            final amount = double.tryParse(controller.text.trim()) ?? 0;
            if (amount <= 0) {
              setState(() => errorText = service.t('enter_valid_amount'));
              return;
            }
            setState(() {
              submitting = true;
              errorText = null;
            });
            final error = await service.transferToGoal(goal.id, amount);
            if (error != null) {
              setState(() {
                submitting = false;
                errorText = error;
              });
              return;
            }
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
                        child: Icon(goal.icon, color: AppColors.accentDeep, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(service.t('deposit_title'),
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Text(goal.name,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: submitting ? null : () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoStat(
                          label: service.t('ledger_remaining'),
                          value: '฿${service.balance.toStringAsFixed(2)}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InfoStat(
                          label: service.t('needed_more'),
                          value: '฿${remaining.toStringAsFixed(2)}',
                          valueColor: AppColors.accentDeep,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AppTextField(
                    controller: controller,
                    hint: '0.00',
                    autofocus: true,
                    prefixText: '฿ ',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    errorText: errorText,
                    onChanged: (_) {
                      if (errorText != null) setState(() => errorText = null);
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (maxTransferable > 0) ...[
                        _QuickAmountChip(
                          label: service.t('quarter'),
                          onTap: () => applyQuickAmount(maxTransferable * 0.25),
                        ),
                        _QuickAmountChip(
                          label: service.t('half'),
                          onTap: () => applyQuickAmount(maxTransferable * 0.5),
                        ),
                        _QuickAmountChip(
                          label: service.t('full_remaining'),
                          onTap: () => applyQuickAmount(maxTransferable.toDouble()),
                          emphasized: true,
                        ),
                      ] else
                        Text(service.t('insufficient_balance'),
                            style: TextStyle(color: AppColors.danger, fontSize: 12.5)),
                    ],
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
                          onPressed: submitting ? null : () => Navigator.pop(dialogContext),
                          child: Text(service.t('cancel'),
                              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
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
                          onPressed: submitting ? null : submit,
                          child: submitting
                              ? SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.inkOn))
                              : Text(service.t('transfer'),
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

/// การ์ดข้อมูลเล็กๆ (Ledger คงเหลือ / ต้องการอีก) ในกล่องเติมเงินเข้าเป้าหมาย
class _InfoStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoStat({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: valueColor ?? AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// ชิปเลือกจำนวนเงินด่วน (25% / 50% / เต็มจำนวนที่ขาด) ในกล่องเติมเงินเข้าเป้าหมาย
class _QuickAmountChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  const _QuickAmountChip({required this.label, required this.onTap, this.emphasized = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized ? AppColors.accentBg : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: emphasized ? AppColors.accentDeep : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}