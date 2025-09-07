import 'package:cloud_firestore/cloud_firestore.dart';

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

