/// Transactions list with filter controls (date range, category).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'package:personal_tracker/services/transactions_service.dart';
import 'package:personal_tracker/widgets/error_view.dart';
import 'add_edit_transaction_page.dart';

/// Lists transactions for the selected period and allows quick filtering.
class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  DateTime get _firstOfMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  DateTime get _firstOfNextMonth {
    final f = _firstOfMonth;
    return DateTime(f.year, f.month + 1, 1);
  }

  // Filters are handled via AppState (Provider)

  Query<Map<String, dynamic>> _baseQuery() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('transactions');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _txStream() {
    // Delegate to service for reuse and single-responsibility.
    final app = context.watch<AppState>();
    return TransactionsService(_uid).streamInRange(app.range);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _categoriesStream() {
    final app = context.watch<AppState>();
    return TransactionsService(_uid).streamForCategories(app.range);
  }

  Future<void> _pickDate() async {
    final app = context.read<AppState>();
    final initial = app.range.start;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      // Map the single picked date to a one-day range [start, nextDay)
      final start = DateTime(picked.year, picked.month, picked.day);
      final end = DateTime(picked.year, picked.month, picked.day + 1);
      context.read<AppState>().setRange(DateTimeRange(start: start, end: end));
    }
  }

  void _clearFilters() {
    context.read<AppState>().resetFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event),
                    label: Consumer<AppState>(
                      builder: (_, app, __) {
                        final d = app.range.start;
                        final label = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                        return Text(label);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _categoriesStream(),
                  builder: (context, snap) {
                    final docs = snap.data?.docs ?? [];
                    final set = <String>{'All'};
                    for (final d in docs) {
                      final cat = (d.data()['category'] as String?)?.trim();
                      if (cat != null && cat.isNotEmpty) set.add(cat);
                    }
                    final items =
                        set
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c,
                                child: Text(c),
                              ),
                            )
                            .toList()
                          ..sort(
                            (a, b) => a.value!.toLowerCase().compareTo(
                              b.value!.toLowerCase(),
                            ),
                          );
                    return SizedBox(
                      width: 160,
                      child: Consumer<AppState>(
                        builder: (_, app, __) =>
                            DropdownButtonFormField<String>(
                              value: app.categoryFilter,
                              items: items,
                              onChanged: (v) => app.setCategory(v ?? 'All'),
                              decoration: const InputDecoration(
                                isDense: true,
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Reset filters',
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _txStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ErrorView(
                    title: "Couldn't load transactions",
                    message: 'Please check your connection and try again.',
                    details: snapshot.error.toString(),
                    onRetry: () => setState(() {}),
                  );
                }
                var docs = snapshot.data?.docs ?? [];
                final category = context.watch<AppState>().categoryFilter;
                if (category != 'All') {
                  docs = docs
                      .where(
                        (d) => (d.data()['category'] as String?) == category,
                      )
                      .toList();
                }
                if (docs.isEmpty) {
                  return const Center(child: Text('No transactions'));
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final isIncome =
                        (data['type'] as String?)?.toLowerCase() == 'income';
                    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                    final category = (data['category'] as String?) ?? 'General';
                    final desc = (data['description'] as String?) ?? '';
                    final date = (data['date'] as Timestamp?)?.toDate();
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isIncome
                            ? Colors.green.withOpacity(0.15)
                            : Colors.red.withOpacity(0.15),
                        child: Icon(
                          isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isIncome ? Colors.green : Colors.red,
                        ),
                      ),
                      title: Text(
                        '${isIncome ? '+' : '-'} ${amount.toStringAsFixed(2)} • $category',
                      ),
                      subtitle: Text(
                        [
                          if (date != null)
                            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                          if (desc.isNotEmpty) desc,
                        ].join('  •  '),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
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
