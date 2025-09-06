import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  AppState() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    _range = DateTimeRange(start: start, end: end);
  }

  DateTimeRange _range = DateTimeRange(start: DateTime(2000), end: DateTime(2000));
  String _categoryFilter = 'All';

  DateTimeRange get range => _range;
  String get categoryFilter => _categoryFilter;

  String get monthKey => '${_range.start.year}-${_range.start.month.toString().padLeft(2, '0')}';

  void setRange(DateTimeRange newRange) {
    if (newRange != _range) {
      _range = newRange;
      notifyListeners();
    }
  }

  void setCategory(String category) {
    if (category != _categoryFilter) {
      _categoryFilter = category;
      notifyListeners();
    }
  }

  void resetFilters() {
    final start = DateTime(_range.start.year, _range.start.month, 1);
    final end = DateTime(start.year, start.month + 1, 1);
    _range = DateTimeRange(start: start, end: end);
    _categoryFilter = 'All';
    notifyListeners();
  }
}

