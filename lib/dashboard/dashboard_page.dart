import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:personal_tracker/transactions/add_edit_transaction_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Stream<QuerySnapshot<Map<String, dynamic>>> _txStream({required DateTime from, required DateTime to}) {
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('transactions');
    return col
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('date', isLessThan: Timestamp.fromDate(to))
        .orderBy('date', descending: true)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _budgetDocStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('settings')
        .doc('budget')
        .snapshots();
  }

  DateTime get _firstOfMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  DateTime get _firstOfNextMonth {
    final f = _firstOfMonth;
    return DateTime(f.year, f.month + 1, 1);
  }

  Future<void> _setBudgetDialog([double? current]) async {
    final controller = TextEditingController(text: current?.toStringAsFixed(2) ?? '');
    final value = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Monthly Budget'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(prefixText: '', labelText: 'Amount'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text.replaceAll(',', ''));
                if (parsed == null) return;
                Navigator.pop(context, parsed);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (value != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('budget')
          .set({'monthlyLimit': value}, SetOptions(merge: true));
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
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('transactions')
          .add({
        'type': type,
        'amount': amount,
        'note': noteCtrl.text.trim(),
        'date': Timestamp.now(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final from = _firstOfMonth;
    final to = _firstOfNextMonth;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _budgetDocStream(),
      builder: (context, budgetSnap) {
        final budget = (budgetSnap.data?.data()?['monthlyLimit'] as num?)?.toDouble() ?? 0.0;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _txStream(from: from, to: to),
          builder: (context, txSnap) {
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
                  _statCard(context, label: 'Remaining Budget', amount: remaining, color: Colors.blueGrey,
                      subtitle: 'Monthly limit: ${budget.toStringAsFixed(2)}'),
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
        final note = (d['note'] as String?) ?? '';
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
