import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_refs.dart';

/// Service for reading and updating monthly budget limits.
class BudgetService {
  BudgetService(this.uid) : refs = FirestoreRefs(uid);
  final String uid;
  final FirestoreRefs refs;

  /// Streams the default monthly budget stored at users/{uid}/settings/budget.monthlyLimit
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamDefault() => refs.defaultBudget.snapshots();

  /// Streams the month-specific budget override, if any, at users/{uid}/budgets/{monthKey}.limit
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamForMonth(String monthKey) =>
      refs.monthBudget(monthKey).snapshots();

  /// Writes a budget value. If [monthOnly] is true, writes an override for [monthKey];
  /// otherwise writes the default monthlyLimit.
  Future<void> setBudget({required double amount, required bool monthOnly, required String monthKey}) async {
    if (monthOnly) {
      await refs.monthBudget(monthKey).set({'limit': amount}, SetOptions(merge: true));
    } else {
      await refs.defaultBudget.set({'monthlyLimit': amount}, SetOptions(merge: true));
    }
  }
}

