import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/expense.dart';
import '../../models/sale.dart';
import '../../providers/expense_provider.dart';
import '../../providers/sale_provider.dart';
import '../../theme/app_theme.dart';
import 'tabs/reports_tab.dart';

class FinancesScreen extends ConsumerStatefulWidget {
  const FinancesScreen({super.key});

  @override
  ConsumerState<FinancesScreen> createState() => _FinancesScreenState();
}

class _FinancesScreenState extends ConsumerState<FinancesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finances'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Dépenses'),
            Tab(text: 'Ventes'),
            Tab(text: 'Rapports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_ExpensesTab(), _SalesTab(), ReportsTab()],
      ),
    );
  }
}

class _ExpensesTab extends ConsumerWidget {
  const _ExpensesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expenseListProvider);
    return Scaffold(
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (list) => list.isEmpty
            ? _empty(Icons.money_off, 'Aucune dépense')
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (ctx, i) => _ExpenseRow(expense: list[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/finances/expense/new'),
        icon: const Icon(Icons.add),
        label: const Text('Dépense'),
        backgroundColor: AppColors.red,
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.expense});
  final Expense expense;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.red.withValues(alpha: 0.15),
          child: const Icon(Icons.money_off, color: AppColors.red),
        ),
        title: Text('${expense.amount.toStringAsFixed(0)} TND',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            '${_scopeLabel(expense.scope)} · ${expense.category} · ${expense.date}',
            overflow: TextOverflow.ellipsis, maxLines: 2),
      ),
    );
  }

  String _scopeLabel(String s) {
    switch (s) {
      case ExpenseScope.animal:
        return 'Animal';
      case ExpenseScope.crop:
        return 'Culture';
      case ExpenseScope.field:
        return 'Champ';
      default:
        return 'Général';
    }
  }
}

class _SalesTab extends ConsumerWidget {
  const _SalesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesListProvider);
    return Scaffold(
      body: salesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (list) => list.isEmpty
            ? _empty(Icons.sell, 'Aucune vente')
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (ctx, i) => _SaleRow(sale: list[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/finances/sale/new'),
        icon: const Icon(Icons.add),
        label: const Text('Vente'),
        backgroundColor: AppColors.green,
      ),
    );
  }
}

class _SaleRow extends StatelessWidget {
  const _SaleRow({required this.sale});
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.green.withValues(alpha: 0.15),
          child: const Icon(Icons.attach_money, color: AppColors.green),
        ),
        title: Text('${sale.totalPrice.toStringAsFixed(0)} TND',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            '${_scopeLabel(sale.scope)} · ${sale.quantity.toStringAsFixed(0)} ${_unitLabel(sale.unit)} · ${sale.saleDate}',
            overflow: TextOverflow.ellipsis, maxLines: 2),
        trailing: sale.buyerName != null
            ? ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 100),
                child: Text(sale.buyerName!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)))
            : null,
      ),
    );
  }

  String _scopeLabel(String s) {
    switch (s) {
      case SaleScope.animal:
        return 'Animal';
      case SaleScope.crop:
        return 'Culture';
      case SaleScope.product:
        return 'Produit';
      default:
        return 'Autre';
    }
  }

  String _unitLabel(String u) {
    switch (u) {
      case SaleUnit.grandeCaisse:
        return 'Gd caisse';
      case SaleUnit.petiteCaisse:
        return 'Pte caisse';
      case SaleUnit.kg:
        return 'kg';
      case SaleUnit.litre:
        return 'L';
      default:
        return 'pcs';
    }
  }
}

Widget _empty(IconData icon, String text) => Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(fontSize: 18, color: Colors.grey[700])),
        ],
      ),
    );
