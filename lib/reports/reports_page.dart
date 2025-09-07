import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:personal_tracker/widgets/error_view.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

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
        .collection('users')
        .doc(_uid)
        .collection('transactions')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('date', isLessThan: Timestamp.fromDate(to))
        .orderBy('date')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final monthKey = '${_firstOfMonth.year}-${_firstOfMonth.month.toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(title: Text('Reports · $monthKey')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _txStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorView(
              title: "Couldn't load reports",
              message: 'Please check your connection and try again.',
              details: snap.error.toString(),
            );
          }
          final docs = snap.data?.docs ?? [];

          // Aggregate spending by category (expenses only)
          final byCategory = <String, double>{};
          final byWeek = <int, double>{};
          double totalExpenses = 0;
          for (final d in docs) {
            final data = d.data();
            final type = (data['type'] as String?)?.toLowerCase();
            if (type != 'expense') continue; // spending only for insights
            final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final category = (data['category'] as String?)?.trim().isNotEmpty == true
                ? (data['category'] as String)
                : 'General';
            final ts = data['date'] as Timestamp?;
            final dt = ts?.toDate() ?? DateTime.now();
            byCategory.update(category, (v) => v + amount, ifAbsent: () => amount);
            final weekIndex = _weekOfMonth(dt);
            byWeek.update(weekIndex, (v) => v + amount, ifAbsent: () => amount);
            totalExpenses += amount;
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionTitle(context, 'Spending by Category'),
                  const SizedBox(height: 8),
                  if (byCategory.isEmpty)
                    const _EmptyHint('No expenses this month')
                  else
                    _CategoryPie(byCategory: byCategory, total: totalExpenses),
                  const SizedBox(height: 24),
                  _sectionTitle(context, 'Weekly Spending'),
                  const SizedBox(height: 8),
                  if (byWeek.isEmpty)
                    const _EmptyHint('No weekly data yet')
                  else
                    _WeeklyBar(byWeek: byWeek),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  int _weekOfMonth(DateTime date) {
    // Simple week-of-month: weeks start on Monday, values 1..6 (covers long months)
    final first = _firstOfMonth;
    final firstWeekday = first.weekday; // 1..7
    final offset = (firstWeekday - DateTime.monday) % 7; // leading days before first Monday
    final dayOfPeriod = date.day + offset; // shift so first Monday starts at 1
    return ((dayOfPeriod - 1) ~/ 7) + 1;
  }

  Widget _sectionTitle(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium,
      );
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        height: 180,
        alignment: Alignment.center,
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      );
}

class _CategoryPie extends StatelessWidget {
  const _CategoryPie({required this.byCategory, required this.total});
  final Map<String, double> byCategory;
  final double total;

  @override
  Widget build(BuildContext context) {
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final colors = _palette(context);
    final sections = <PieChartSectionData>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final pct = total > 0 ? (e.value / total) * 100 : 0;
      sections.add(
        PieChartSectionData(
          color: colors[i % colors.length],
          value: e.value,
          title: '${pct.toStringAsFixed(0)}%',
          radius: 60,
          titleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 34,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (var i = 0; i < entries.length; i++)
                  _legendItem(colors[i % colors.length], entries[i].key, entries[i].value),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label, double value) {
    return Chip(
      avatar: CircleAvatar(backgroundColor: color, radius: 8),
      label: Text('$label  ·  ${value.toStringAsFixed(2)}'),
    );
  }

  List<Color> _palette(BuildContext context) {
    final base = Theme.of(context).colorScheme;
    return [
      base.primary,
      base.secondary,
      Colors.teal,
      Colors.indigo,
      Colors.orange,
      Colors.pink,
      Colors.cyan,
      Colors.brown,
      Colors.deepPurple,
      Colors.amber,
    ].map((c) => _tint(c, 0.9)).toList();
  }

  Color _tint(Color c, double amount) {
    return Color.lerp(c, Colors.black, 1 - amount) ?? c;
  }
}

class _WeeklyBar extends StatelessWidget {
  const _WeeklyBar({required this.byWeek});
  final Map<int, double> byWeek; // 1..6 -> total

  @override
  Widget build(BuildContext context) {
    final maxVal = (byWeek.values.isEmpty ? 0.0 : byWeek.values.reduce(max)).clamp(0.0, double.infinity);
    final bars = List.generate(6, (i) {
      final week = i + 1;
      final v = (byWeek[week] ?? 0).toDouble();
      return BarChartGroupData(
        x: week,
        barRods: [
          BarChartRodData(
            toY: v,
            color: Theme.of(context).colorScheme.primary,
            width: 18,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          )
        ],
      );
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SizedBox(
          height: 260,
          child: BarChart(
            BarChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              maxY: maxVal == 0 ? 100 : (maxVal * 1.2),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 36, interval: maxVal == 0 ? 20 : null),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('W${value.toInt()}', style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ),
                ),
              ),
              barGroups: bars,
            ),
          ),
        ),
      ),
    );
  }
}
