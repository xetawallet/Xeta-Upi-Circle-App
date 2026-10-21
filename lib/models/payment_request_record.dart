import 'request_draft.dart';
import 'trusted_person.dart';

enum RequestStatus { requestSent, proofSaved }

class PaymentRequestRecord {
  const PaymentRequestRecord({
    required this.id,
    required this.createdAtIso,
    required this.channel,
    required this.helper,
    required this.draft,
    this.status = RequestStatus.requestSent,
    this.proofImagePath,
    this.proofMessage,
    this.proofSavedAtIso,
    this.cashbackEarned,
  });

  final String id;
  final String createdAtIso;
  final String channel;
  final TrustedPerson helper;
  final RequestDraft draft;
  final RequestStatus status;
  final String? proofImagePath;
  final String? proofMessage;
  final String? proofSavedAtIso;
  final double? cashbackEarned;

  bool get isProofSaved => status == RequestStatus.proofSaved;
  bool get hasProofImage =>
      proofImagePath != null && proofImagePath!.isNotEmpty;
  bool get hasProofMessage =>
      proofMessage != null && proofMessage!.trim().isNotEmpty;

  PaymentRequestRecord copyWith({
    String? id,
    String? createdAtIso,
    String? channel,
    TrustedPerson? helper,
    RequestDraft? draft,
    RequestStatus? status,
    String? proofImagePath,
    String? proofMessage,
    String? proofSavedAtIso,
    double? cashbackEarned,
  }) {
    return PaymentRequestRecord(
      id: id ?? this.id,
      createdAtIso: createdAtIso ?? this.createdAtIso,
      channel: channel ?? this.channel,
      helper: helper ?? this.helper,
      draft: draft ?? this.draft,
      status: status ?? this.status,
      proofImagePath: proofImagePath ?? this.proofImagePath,
      proofMessage: proofMessage ?? this.proofMessage,
      proofSavedAtIso: proofSavedAtIso ?? this.proofSavedAtIso,
      cashbackEarned: cashbackEarned ?? this.cashbackEarned,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'createdAtIso': createdAtIso,
    'channel': channel,
    'helper': helper.toJson(),
    'draft': draft.toJson(),
    'status': status.name,
    'proofImagePath': proofImagePath,
    'proofMessage': proofMessage,
    'proofSavedAtIso': proofSavedAtIso,
    'cashbackEarned': cashbackEarned,
  };

  factory PaymentRequestRecord.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] as String?;

    return PaymentRequestRecord(
      id: json['id'] as String,
      createdAtIso: json['createdAtIso'] as String,
      channel: json['channel'] as String,
      helper: TrustedPerson.fromJson(
        Map<String, dynamic>.from(json['helper'] as Map),
      ),
      draft: RequestDraft.fromJson(
        Map<String, dynamic>.from(json['draft'] as Map),
      ),
      status: _statusFromStorage(rawStatus),
      proofImagePath: json['proofImagePath'] as String?,
      proofMessage: json['proofMessage'] as String?,
      proofSavedAtIso:
          json['proofSavedAtIso'] as String? ??
          json['paymentReceivedAtIso'] as String?,
      cashbackEarned: json['cashbackEarned'] != null ? (json['cashbackEarned'] as num).toDouble() : null,
    );
  }

  static RequestStatus _statusFromStorage(String? value) {
    switch (value) {
      case 'completed':
      case 'paymentReceived':
      case 'proofSaved':
        return RequestStatus.proofSaved;
      case 'pending':
      case 'requestSent':
      default:
        return RequestStatus.requestSent;
    }
  }
}
