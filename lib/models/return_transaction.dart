class ReturnTransaction {
  const ReturnTransaction({
    required this.id,
    required this.amount,
    required this.dateIso,
    required this.paidViaApp,
  });

  final String id;
  final double amount;
  final String dateIso;
  final String paidViaApp;

  ReturnTransaction copyWith({
    String? id,
    double? amount,
    String? dateIso,
    String? paidViaApp,
  }) {
    return ReturnTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      dateIso: dateIso ?? this.dateIso,
      paidViaApp: paidViaApp ?? this.paidViaApp,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'amount': amount,
    'dateIso': dateIso,
    'paidViaApp': paidViaApp,
  };

  factory ReturnTransaction.fromJson(Map<String, dynamic> json) {
    return ReturnTransaction(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      dateIso: json['dateIso'] as String,
      paidViaApp: json['paidViaApp'] as String,
    );
  }
}
