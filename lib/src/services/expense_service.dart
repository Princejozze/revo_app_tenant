import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';

class ExpenseService extends ChangeNotifier {
  static const _key = 'expenses_data_v1';
  final List<Expense> _expenses = [];

  List<Expense> get expenses => List.unmodifiable(_expenses);

  ExpenseService() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final list = (json.decode(raw) as List).cast<Map<String, dynamic>>();
      _expenses
        ..clear()
        ..addAll(list.map(Expense.fromJson));
      notifyListeners();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(_expenses.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  void addExpense({
    required String category,
    required double amount,
    DateTime? date,
    String? notes,
    String? houseId,
    String? houseName,
  }) {
    final exp = Expense(
      id: 'exp-${DateTime.now().millisecondsSinceEpoch}',
      category: category,
      amount: amount,
      date: date ?? DateTime.now(),
      notes: notes,
      houseId: houseId,
      houseName: houseName,
    );
    _expenses.add(exp);
    notifyListeners();
    _save();
  }

  void removeExpense(String id) {
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
    _save();
  }

  // Sum by category within a date range
  Map<String, double> sumByCategory({required DateTime start, required DateTime end}) {
    final map = <String, double>{};
    for (final e in _expenses) {
      if (e.date.isBefore(start) || e.date.isAfter(end)) continue;
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  // Sum total expenses within a date range
  double sumTotal({required DateTime start, required DateTime end}) {
    double total = 0;
    for (final e in _expenses) {
      if (e.date.isBefore(start) || e.date.isAfter(end)) continue;
      total += e.amount;
    }
    return total;
  }

  // Sum expenses by property within a date range
  Map<String, double> sumByProperty({required DateTime start, required DateTime end}) {
    final map = <String, double>{};
    for (final e in _expenses) {
      if (e.date.isBefore(start) || e.date.isAfter(end)) continue;
      final key = e.houseName ?? e.houseId ?? 'Unknown';
      map[key] = (map[key] ?? 0) + e.amount;
    }
    return map;
  }

  // Sum expenses per month for a range
  Map<String, double> sumByMonth({required DateTime start, required DateTime end}) {
    final monthFmt = DateFormat('MMM yy');
    final map = <String, double>{};
    // initialize
    int months = (end.year - start.year) * 12 + (end.month - start.month) + 1;
    for (int i = 0; i < months; i++) {
      final dt = DateTime(start.year, start.month + i, 1);
      map[monthFmt.format(dt)] = 0;
    }
    for (final e in _expenses) {
      if (e.date.isBefore(start) || e.date.isAfter(end)) continue;
      final key = monthFmt.format(DateTime(e.date.year, e.date.month, 1));
      map[key] = (map[key] ?? 0) + e.amount;
    }
    return map;
  }
}
