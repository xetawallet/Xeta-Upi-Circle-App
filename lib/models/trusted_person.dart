import 'return_transaction.dart';

class TrustedPerson {
  const TrustedPerson({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.upiId = '',
    this.returns = const [],
  });

  final String id;
  final String name;
  final String phoneNumber;
  final String upiId;
  final List<ReturnTransaction> returns;

  TrustedPerson copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? upiId,
    List<ReturnTransaction>? returns,
  }) {
    return TrustedPerson(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      upiId: upiId ?? this.upiId,
      returns: returns ?? this.returns,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'phoneNumber': phoneNumber,
    'upiId': upiId,
    'returns': returns.map((r) => r.toJson()).toList(),
  };

  factory TrustedPerson.fromJson(Map<String, dynamic> json) {
    return TrustedPerson(
      id: json['id'] as String,
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String,
      upiId: json['upiId'] as String? ?? '',
      returns: (json['returns'] as List<dynamic>?)
              ?.map((item) => ReturnTransaction.fromJson(
                  Map<String, dynamic>.from(item as Map)))
              .toList() ??
          const [],
    );
  }
}
