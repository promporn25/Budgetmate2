import 'package:budgetmate/screens/app_theme.dart';
import 'package:budgetmate/screens/income%20expense%20overview.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import 'wallet_screen.dart';

/// หน้า Income/Expense (3.4.9)
class IncomeExpenseScreen extends StatelessWidget {
  const IncomeExpenseScreen({super.key});

  void _handleBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const WalletScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'ย้อนกลับ',
          onPressed: () => _handleBack(context),
        ),
        title: Text(service.t('income_expense'),
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ),
      body: const IncomeExpenseOverview(),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }
}