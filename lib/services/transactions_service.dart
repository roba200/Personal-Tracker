import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'firestore_refs.dart';

class TransactionsService {
  TransactionsService(this.uid) : refs = FirestoreRefs(uid);
  final String uid;
  final FirestoreRefs refs;

  /// Streams transactions within [range], ordered by date descending.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamInRange(
    DateTimeRange range,
  ) {
    return refs.transactions
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('date', isLessThan: Timestamp.fromDate(range.end))
        .orderBy('date', descending: true)
        .snapshots();
  }

  /// Streams transactions within [range] without category filtering; useful to derive dynamic category lists.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamForCategories(
    DateTimeRange range,
  ) {
    return refs.transactions
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('date', isLessThan: Timestamp.fromDate(range.end))
        .snapshots();
  }

  /// Adds a transaction document.
  Future<void> add({
    required String type, // 'income' | 'expense'
    required double amount,
    required String category,
    String? description,
    required DateTime date,
  }) async {
    await refs.transactions.add({
      'type': type.toLowerCase(),
      'amount': amount,
      'category': category,
      if (description != null) 'description': description,
      // Keep backward-compat: also store as 'note' so older UIs still read it
      if (description != null) 'note': description,
      'date': Timestamp.fromDate(date),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
