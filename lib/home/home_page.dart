import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:personal_tracker/dashboard/dashboard_page.dart';
import 'package:personal_tracker/transactions/add_edit_transaction_page.dart';
import 'package:personal_tracker/transactions/transactions_page.dart';
import 'package:personal_tracker/reports/reports_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Unknown';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Finance Tracker'),
      ),
      drawer: _AppDrawer(email: email),
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

/// App drawer for navigating between core sections and signing out.
class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text(''),
              accountEmail: Text(email),
              currentAccountPicture: const CircleAvatar(child: Icon(Icons.person)),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context); // just close drawer, already on dashboard
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Transactions'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TransactionsPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.insights_outlined),
              title: const Text('Reports'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReportsPage()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
