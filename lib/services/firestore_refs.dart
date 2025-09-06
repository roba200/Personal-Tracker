import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralizes Firestore collection/document references for a given user.
/// Keeping paths in one place avoids typos and makes future schema changes easier.
class FirestoreRefs {
  FirestoreRefs(this.uid);
  final String uid;

  /// users/{uid}
  DocumentReference<Map<String, dynamic>> get userDoc =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  /// users/{uid}/transactions
  CollectionReference<Map<String, dynamic>> get transactions =>
      userDoc.collection('transactions');

  /// users/{uid}/settings
  CollectionReference<Map<String, dynamic>> get settings =>
      userDoc.collection('settings');

  /// users/{uid}/settings/budget
  DocumentReference<Map<String, dynamic>> get defaultBudget =>
      settings.doc('budget');

  /// users/{uid}/budgets/{yyyy-MM}
  DocumentReference<Map<String, dynamic>> monthBudget(String monthKey) =>
      userDoc.collection('budgets').doc(monthKey);
}

