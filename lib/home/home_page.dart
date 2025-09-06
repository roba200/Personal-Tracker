import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:personal_tracker/dashboard/dashboard_page.dart';
import 'package:personal_tracker/transactions/add_edit_transaction_page.dart';
import 'package:personal_tracker/transactions/transactions_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Unknown';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Finance Tracker'),
        actions: [
          IconButton(
            tooltip: 'Transactions',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TransactionsPage()),
              );
            },
            icon: const Icon(Icons.list_alt),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Welcome, $email', style: Theme.of(context).textTheme.titleMedium),
          ),
          const Expanded(child: DashboardPage()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddEditTransactionPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Transaction'),
      ),
    );
  }
}
