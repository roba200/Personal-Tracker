import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'add_edit_transaction_page.dart';

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

  DateTimeRange? _range;
  String _category = 'All';

  @override
  void initState() {
    super.initState();
    _range = DateTimeRange(start: _firstOfMonth, end: _firstOfNextMonth);
  }

  Query<Map<String, dynamic>> _baseQuery() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('transactions');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _txStream() {
    // Fetch by date only to avoid requiring a composite index when also filtering by category.
    // Category filtering is applied client-side below.
    var q = _baseQuery();
    if (_range != null) {
      q = q
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(_range!.start))
          .where('date', isLessThan: Timestamp.fromDate(_range!.end));
    }
    q = q.orderBy('date', descending: true);
    return q.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _categoriesStream() {
    // Same as _txStream but without category filter to collect category values.
    var q = _baseQuery();
    if (_range != null) {
      q = q
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(_range!.start))
          .where('date', isLessThan: Timestamp.fromDate(_range!.end));
    }
    return q.snapshots();
  }

  Future<void> _pickRange() async {
    final initial = _range ?? DateTimeRange(start: _firstOfMonth, end: _firstOfNextMonth);
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _range = picked);
    }
  }

  void _clearFilters() {
    setState(() {
      _range = DateTimeRange(start: _firstOfMonth, end: _firstOfNextMonth);
      _category = 'All';
    });
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
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(_range == null
                        ? 'All time'
                        : '${_range!.start.year}-${_range!.start.month.toString().padLeft(2, '0')}-${_range!.start.day.toString().padLeft(2, '0')}  →  '
                          '${_range!.end.year}-${_range!.end.month.toString().padLeft(2, '0')}-${_range!.end.day.toString().padLeft(2, '0')}'),
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
                    final items = set
                        .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                        .toList()
                      ..sort((a, b) => a.value!.toLowerCase().compareTo(b.value!.toLowerCase()));
                    return SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        items: items,
                        onChanged: (v) => setState(() => _category = v ?? 'All'),
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Failed to load transactions.\n\n${snapshot.error}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }
                var docs = snapshot.data?.docs ?? [];
                if (_category != 'All') {
                  docs = docs
                      .where((d) => (d.data()['category'] as String?) == _category)
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
