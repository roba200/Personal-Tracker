import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'add_edit_transaction_page.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  DateTime get _firstOfMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  DateTime get _firstOfNextMonth {
    final f = _firstOfMonth;
    return DateTime(f.year, f.month + 1, 1);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _txStream() {
    final from = _firstOfMonth;
    final to = _firstOfNextMonth;
    return FirebaseFirestore.instance
        .collection('users').doc(_uid)
        .collection('transactions')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('date', isLessThan: Timestamp.fromDate(to))
        .orderBy('date', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _txStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No transactions for this month'));
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final isIncome = (data['type'] as String?)?.toLowerCase() == 'income';
              final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
              final category = (data['category'] as String?) ?? 'General';
              final desc = (data['description'] as String?) ?? '';
              final date = (data['date'] as Timestamp?)?.toDate();
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isIncome ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                  child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: isIncome ? Colors.green : Colors.red),
                ),
                title: Text('${isIncome ? '+' : '-'} ${amount.toStringAsFixed(2)} • $category'),
                subtitle: Text([
                  if (date != null) '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                  if (desc.isNotEmpty) desc,
                ].join('  •  ')),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddEditTransactionPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }
}

