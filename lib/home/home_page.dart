import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:personal_tracker/dashboard/dashboard_page.dart';

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
    );
  }
}
