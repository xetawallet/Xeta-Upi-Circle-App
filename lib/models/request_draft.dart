class RequestDraft {
  const RequestDraft({
    required this.rawValue,
    required this.sourceLabel,
    this.upiId,
    this.payeeName,
    this.amount,
    this.note,
    this.mc,
    this.cu,
  });

  final String rawValue;
  final String sourceLabel;
  final String? upiId;
  final String? payeeName;
  final String? amount;
  final String? note;
  final String? mc;
  final String? cu;

  String get title {
    if (payeeName != null && payeeName!.trim().isNotEmpty) {
      return payeeName!.trim();
    }
    if (upiId != null && upiId!.trim().isNotEmpty) {
      return upiId!.trim();
    }
    return 'UPI request ready';
  }

  String get subtitle {
    final parts = <String>[
      if (amount != null && amount!.trim().isNotEmpty) 'Amount Rs $amount',
      if (note != null && note!.trim().isNotEmpty) note!.trim(),
      sourceLabel,
    ];
    return parts.join(' • ');
  }

  String get shareValue {
    if (upiId == null || upiId!.trim().isEmpty) {
      return rawValue;
    }

    return 'upi://pay?$intentQuery';
  }

  String get qrValue => shareValue;

  String get intentQuery => upiParameters.entries
      .map(
        (entry) =>
            '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
      )
      .join('&');

  Map<String, String> get upiParameters {
    if (upiId == null || upiId!.trim().isEmpty) {
      return const <String, String>{};
    }

    return <String, String>{
      'pa': upiId!.trim(),
      if (payeeName != null && payeeName!.trim().isNotEmpty)
        'pn': payeeName!.trim(),
      if (amount != null && amount!.trim().isNotEmpty) 'am': amount!.trim(),
      if (note != null && note!.trim().isNotEmpty) 'tn': note!.trim(),
      if (mc != null && mc!.trim().isNotEmpty) 'mc': mc!.trim(),
      if (cu != null && cu!.trim().isNotEmpty) 'cu': cu!.trim(),
    };
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'rawValue': rawValue,
    'sourceLabel': sourceLabel,
    'upiId': upiId,
    'payeeName': payeeName,
    'amount': amount,
    'note': note,
    'mc': mc,
    'cu': cu,
  };

  factory RequestDraft.fromJson(Map<String, dynamic> json) {
    return RequestDraft(
      rawValue: json['rawValue'] as String,
      sourceLabel: json['sourceLabel'] as String,
      upiId: json['upiId'] as String?,
      payeeName: json['payeeName'] as String?,
      amount: json['amount'] as String?,
      note: json['note'] as String?,
      mc: json['mc'] as String?,
      cu: json['cu'] as String?,
    );
  }
}
