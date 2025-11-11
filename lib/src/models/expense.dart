class Expense {
  final String id;
  final String category; // e.g., Maintenance, Utilities, Taxes, Salaries, Other
  final double amount;
  final DateTime date;
  final String? notes;
  final String? houseId; // optional: link to a property by id
  final String? houseName; // optional: for display if needed

  Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.date,
    this.notes,
    this.houseId,
    this.houseName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'amount': amount,
        'date': date.toIso8601String(),
        'notes': notes,
        'houseId': houseId,
        'houseName': houseName,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        category: json['category'] as String,
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        notes: json['notes'] as String?,
        houseId: json['houseId'] as String?,
        houseName: json['houseName'] as String?,
      );
}
