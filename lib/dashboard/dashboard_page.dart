/// Dashboard: monthly overview of income, expenses, and budget progress.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:personal_tracker/state/app_state.dart';
import 'package:personal_tracker/transactions/add_edit_transaction_page.dart';
import 'package:personal_tracker/services/transactions_service.dart';
import 'package:personal_tracker/services/budget_service.dart';

/// Displays summary cards, budget progress, quick actions, and recent list.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;


  // Transaction stream for a specific date range.
  Stream<QuerySnapshot<Map<String, dynamic>>> _txStream({required DateTime from, required DateTime to}) {
    final service = TransactionsService(_uid);
    return service.streamInRange(DateTimeRange(start: from, end: to));
  }

  // Default (global) monthly budget setting
  Stream<DocumentSnapshot<Map<String, dynamic>>> _budgetDocStream() =>
      BudgetService(_uid).streamDefault();

  // Month-specific budget override: users/{uid}/budgets/{yyyy-MM}
  Stream<DocumentSnapshot<Map<String, dynamic>>> _monthBudgetStream() =>
      BudgetService(_uid).streamForMonth(_monthKey);

  DateTime get _firstOfMonth {
    final app = context.read<AppState>();
    return DateTime(app.range.start.year, app.range.start.month, 1);
  }

  DateTime get _firstOfNextMonth {
    final f = _firstOfMonth;
    return DateTime(f.year, f.month + 1, 1);
  }

  String get _monthKey {
    final app = context.read<AppState>();
    return '${app.range.start.year}-${app.range.start.month.toString().padLeft(2, '0')}';
  }

  Future<void> _setBudgetDialog([double? current]) async {
    final controller = TextEditingController(text: current?.toStringAsFixed(2) ?? '');
    bool thisMonthOnly = true;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Set Monthly Budget'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(prefixText: '', labelText: 'Amount'),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: thisMonthOnly,
                  onChanged: (v) => setStateDialog(() => thisMonthOnly = v ?? true),
                  title: Text('Apply to ${_monthKey} only'),
                  subtitle: const Text('Uncheck to set a default for all months'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final parsed = double.tryParse(controller.text.replaceAll(',', ''));
                  if (parsed == null) return;
                  Navigator.pop(context, {'amount': parsed, 'monthOnly': thisMonthOnly});
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
    if (result != null) {
      final amount = (result['amount'] as num).toDouble();
      final monthOnly = result['monthOnly'] == true;
      await BudgetService(_uid).setBudget(amount: amount, monthOnly: monthOnly, monthKey: _monthKey);
    }
  }

  Future<void> _quickAddDialog({required String type}) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(type == 'income' ? 'Add Income' : 'Add Expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(amountCtrl.text);
              if (v == null || v <= 0) return;
              Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (res == true) {
      final amount = double.parse(amountCtrl.text);
      await TransactionsService(_uid).add(
        type: type,
        amount: amount,
        category: 'Quick',
        description: noteCtrl.text.trim(),
        date: DateTime.now(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final from = _firstOfMonth;
    final to = _firstOfNextMonth;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _monthBudgetStream(),
      builder: (context, monthSnap) {
        // Prefer month-specific budget; fall back to default monthlyLimit
        final monthLimit = (monthSnap.data?.data()?['limit'] as num?)?.toDouble();
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _budgetDocStream(),
          builder: (context, defaultSnap) {
            final defaultLimit = (defaultSnap.data?.data()?['monthlyLimit'] as num?)?.toDouble();
            final budget = monthLimit ?? defaultLimit ?? 0.0;
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _txStream(from: from, to: to),
          builder: (context, txSnap) {
            if (txSnap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Failed to load dashboard data. Please try again.'),
                ),
              );
            }
            double income = 0, expenses = 0;
            if (txSnap.hasData) {
              for (final d in txSnap.data!.docs) {
                final data = d.data();
                final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                final type = (data['type'] as String?)?.toLowerCase() ?? 'expense';
                if (type == 'income') {
                  income += amount;
                } else {
                  expenses += amount;
                }
              }
            }
            final remaining = budget - expenses;
            final used = expenses;
            final ratio = budget > 0 ? (used / budget).clamp(0.0, 1.0) : 0.0;
            final over = used - budget;
            Color barColor;
            if (budget == 0) {
              barColor = Colors.grey;
            } else if (ratio < 0.5) {
              barColor = Colors.green;
            } else if (ratio < 0.9) {
              barColor = Colors.orange;
            } else {
              barColor = Colors.red;
            }

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: _statCard(context, label: 'Income', amount: income, color: Colors.green)),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard(context, label: 'Expenses', amount: expenses, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _budgetProgressCard(context,
                      budget: budget, used: used, remaining: remaining, ratio: ratio, color: barColor,
                      monthKey: _monthKey, hasMonthOverride: monthLimit != null),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _setBudgetDialog(budget == 0 ? null : budget),
                        icon: const Icon(Icons.account_balance_wallet_outlined),
                        label: Text(budget == 0 ? 'Set Budget' : 'Update Budget'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AddEditTransactionPage(initialType: 'income'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Income'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AddEditTransactionPage(initialType: 'expense'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.remove),
                        label: const Text('Add Expense'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _recentList(txSnap),
                  ),
                ],
              ),
            );
          },
            );
          },
        );
      },
    );
  }

  Widget _statCard(BuildContext context, {required String label, required double amount, required Color color, String? subtitle}) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      color: color.withOpacity(0.07),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(amount.toStringAsFixed(2), style: textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: textTheme.bodySmall),
            ]
          ],
        ),
      ),
    );
  }

  Widget _budgetProgressCard(BuildContext context,
      {required double budget,
      required double used,
      required double remaining,
      required double ratio,
      required Color color,
      required String monthKey,
      required bool hasMonthOverride}) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Monthly Budget ($monthKey)', style: t.titleSmall),
                if (hasMonthOverride)
                  const Tooltip(message: 'This month has its own budget', child: Icon(Icons.event_note, size: 18)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: budget > 0 ? ratio : 0, color: color, minHeight: 10),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _chip(Icons.account_balance_wallet_outlined, 'Limit: ${budget.toStringAsFixed(2)}'),
                _chip(Icons.payments_outlined, 'Spent: ${used.toStringAsFixed(2)}'),
                _chip(
                  remaining >= 0 ? Icons.check_circle_outline : Icons.error_outline,
                  (remaining >= 0
                          ? 'Remaining: ${remaining.toStringAsFixed(2)}'
                          : 'Over: ${(remaining.abs()).toStringAsFixed(2)}'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Chip(avatar: Icon(icon, size: 16), label: Text(label));
  }

  Widget _recentList(AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> txSnap) {
    if (txSnap.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    final docs = txSnap.data?.docs ?? [];
    if (docs.isEmpty) {
      return const Center(child: Text('No transactions this month'));
    }
    return ListView.separated(
      itemCount: docs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final d = docs[i].data();
        final isIncome = (d['type'] as String?)?.toLowerCase() == 'income';
        final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
        final ts = d['date'] as Timestamp?;
        final date = ts?.toDate();
        final note = (d['description'] as String?) ?? (d['note'] as String?) ?? '';
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isIncome ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
            child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: isIncome ? Colors.green : Colors.red),
          ),
          title: Text((isIncome ? '+ ' : '- ') + amount.toStringAsFixed(2)),
          subtitle: Text(note.isEmpty ? (date?.toIso8601String().split('T').first ?? '') : note),
        );
      },
    );
  }
}
