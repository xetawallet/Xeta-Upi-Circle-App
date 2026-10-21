import 'package:flutter/foundation.dart';

import '../models/payment_request_record.dart';
import '../models/request_draft.dart';
import '../models/return_transaction.dart';
import '../models/trusted_person.dart';
import '../services/circle_storage.dart';
import '../services/upi_parser.dart';

class XetaUpiCircleAppController extends ChangeNotifier {
  XetaUpiCircleAppController({
    required CircleStorage storage,
    UpiParser parser = const UpiParser(),
    DateTime Function()? now,
  }) : _storage = storage,
       _parser = parser,
       _now = now ?? DateTime.now;

  final CircleStorage _storage;
  final UpiParser _parser;
  final DateTime Function() _now;

  List<TrustedPerson> _trustedPeople = const <TrustedPerson>[];
  List<PaymentRequestRecord> _requestHistory = const <PaymentRequestRecord>[];
  TrustedPerson? _selectedHelper;
  RequestDraft? _currentDraft;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _statusMessage;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get statusMessage => _statusMessage;
  List<TrustedPerson> get trustedPeople => _trustedPeople;
  List<PaymentRequestRecord> get requestHistory => _requestHistory;
  TrustedPerson? get selectedHelper => _selectedHelper;
  RequestDraft? get currentDraft => _currentDraft;
  bool get canSend => _selectedHelper != null && _currentDraft != null;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _trustedPeople = await _storage.readTrustedPeople();
      _requestHistory = await _storage.readRequestHistory();
      if (_trustedPeople.isNotEmpty) {
        _selectedHelper = _trustedPeople.first;
      }
    } catch (error) {
      _errorMessage = '$error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();
  }

  void selectHelper(String helperId) {
    _selectedHelper = _trustedPeople.firstWhere(
      (person) => person.id == helperId,
      orElse: () => _selectedHelper ?? _trustedPeople.first,
    );
    notifyListeners();
  }

  Future<void> saveTrustedPerson(TrustedPerson person) async {
    _withSaving(() async {
      final index = _trustedPeople.indexWhere((item) => item.id == person.id);
      final updatedPeople = [..._trustedPeople];
      if (index == -1) {
        updatedPeople.add(person);
      } else {
        updatedPeople[index] = person;
      }

      updatedPeople.sort((left, right) => left.name.compareTo(right.name));
      _trustedPeople = updatedPeople;
      _selectedHelper ??= person;
      _selectedHelper = _trustedPeople.firstWhere(
        (item) => item.id == (_selectedHelper?.id ?? person.id),
        orElse: () => person,
      );
      await _storage.writeTrustedPeople(_trustedPeople);
      _statusMessage = null;
    });
  }

  Future<void> deleteTrustedPerson(String helperId) async {
    _withSaving(() async {
      final removedPerson = _trustedPeople.firstWhere(
        (item) => item.id == helperId,
      );
      _trustedPeople = _trustedPeople
          .where((item) => item.id != helperId)
          .toList(growable: false);
      if (_selectedHelper?.id == helperId) {
        _selectedHelper = _trustedPeople.isEmpty ? null : _trustedPeople.first;
      }
      await _storage.writeTrustedPeople(_trustedPeople);
      _statusMessage = '${removedPerson.name} was removed from the circle.';
    });
  }

  Future<void> addReturnTransaction(
    String helperId,
    ReturnTransaction transaction,
  ) async {
    await _withSaving(() async {
      final index = _trustedPeople.indexWhere((item) => item.id == helperId);
      if (index == -1) return;
      final person = _trustedPeople[index];
      final updatedReturns = [...person.returns, transaction];
      final updatedPerson = person.copyWith(returns: updatedReturns);

      final updatedPeople = [..._trustedPeople];
      updatedPeople[index] = updatedPerson;
      _trustedPeople = updatedPeople;

      if (_selectedHelper?.id == helperId) {
        _selectedHelper = updatedPerson;
      }
      await _storage.writeTrustedPeople(_trustedPeople);
    });
  }

  Future<void> removeReturnTransaction(String helperId, String returnId) async {
    await _withSaving(() async {
      final index = _trustedPeople.indexWhere((item) => item.id == helperId);
      if (index == -1) return;
      final person = _trustedPeople[index];
      final updatedPerson = person.copyWith(
        returns: person.returns
            .where((transaction) => transaction.id != returnId)
            .toList(growable: false),
      );
      final updatedPeople = [..._trustedPeople];
      updatedPeople[index] = updatedPerson;
      _trustedPeople = updatedPeople;
      if (_selectedHelper?.id == helperId) _selectedHelper = updatedPerson;
      await _storage.writeTrustedPeople(_trustedPeople);
    });
  }

  void clearDraft() {
    _currentDraft = null;
    _statusMessage = 'Ready to prepare the next payment request.';
    notifyListeners();
  }

  void useHistoricDraft(RequestDraft draft, {String? helperId}) {
    _currentDraft = draft;
    if (helperId != null &&
        _trustedPeople.any((person) => person.id == helperId)) {
      selectHelper(helperId);
      return;
    }
    notifyListeners();
  }

  void createDraftFromInput({
    required String rawInput,
    String? amountText,
    String? noteText,
  }) {
    try {
      _currentDraft = _parser.parse(
        rawInput: rawInput,
        amountText: amountText,
        noteText: noteText,
      );
      _errorMessage = null;
      _statusMessage =
          'QR captured. Review the details, choose your trusted contact, and share it.';
    } on FormatException catch (error) {
      _errorMessage = error.message;
    }
    notifyListeners();
  }

  String buildRequestMessage() {
    final helper = _selectedHelper;
    final draft = _currentDraft;
    if (helper == null || draft == null) {
      throw StateError('A helper and request draft must be selected first.');
    }

    return _buildRequestMessage(helper: helper, draft: draft);
  }

  String buildRequestMessageForRecord(PaymentRequestRecord record) {
    return _buildRequestMessage(helper: record.helper, draft: record.draft);
  }

  String _buildRequestMessage({
    required TrustedPerson helper,
    required RequestDraft draft,
  }) {
    final lines = <String>[
      'Hi ${helper.name},',
      '',
      'Please make this UPI payment for me and send the proof back on WhatsApp.',
      '',
      'Pay To: ${draft.title}',
      if (draft.upiId != null && draft.upiId!.trim().isNotEmpty)
        'UPI ID: ${draft.upiId}',
      'Amount: ${draft.amount != null && draft.amount!.trim().isNotEmpty ? 'Rs ${draft.amount}' : '-'}',
      'Note: ${draft.note != null && draft.note!.trim().isNotEmpty ? draft.note : '-'}',
      '',
      'QR Code: attached image',
      'After paying, please send the payment screenshot and message back.',
      '',
      'I will save the transaction proof later inside Xeta UPI Circle App.',
      '',
      'Pay together as a family and earn cashback. Native UPI apps do not allow you to add a credit card belonging to someone else, even a family member.',
    ];

    return lines.join('\n');
  }

  Future<bool> recordSentRequest({required String channel}) async {
    return recordSentRequestWithId(
      channel: channel,
      requestId: _now().microsecondsSinceEpoch.toString(),
    );
  }

  Future<bool> recordSentRequestWithId({
    required String channel,
    required String requestId,
  }) async {
    final helper = _selectedHelper;
    final draft = _currentDraft;
    if (helper == null || draft == null) {
      return false;
    }

    var saved = false;
    await _withSaving(() async {
      final record = PaymentRequestRecord(
        id: requestId,
        createdAtIso: _now().toIso8601String(),
        channel: channel,
        helper: helper,
        draft: draft,
      );

      final updatedHistory = [record, ..._requestHistory];
      await _storage.writeRequestHistory(updatedHistory);
      _requestHistory = updatedHistory;
      _statusMessage = 'Request shared through $channel and stored locally.';
      saved = true;
    });
    return saved;
  }

  Future<bool> saveProofForRequest({
    required String requestId,
    String? proofImagePath,
    String? proofMessage,
    String? cashbackEarnedText,
  }) async {
    final normalizedMessage = proofMessage?.trim();
    final hasProof =
        (proofImagePath != null && proofImagePath.trim().isNotEmpty) ||
        (normalizedMessage != null && normalizedMessage.isNotEmpty);

    if (!hasProof &&
        (cashbackEarnedText == null || cashbackEarnedText.isEmpty)) {
      _errorMessage =
          'Add a proof image, message, or cashback earned before saving.';
      notifyListeners();
      return false;
    }

    double? cashbackEarned;
    if (cashbackEarnedText != null && cashbackEarnedText.isNotEmpty) {
      cashbackEarned = double.tryParse(cashbackEarnedText);
    }

    var updated = false;
    await _withSaving(() async {
      _requestHistory = _requestHistory
          .map((request) {
            if (request.id != requestId) {
              return request;
            }

            updated = true;
            return request.copyWith(
              status: RequestStatus.proofSaved,
              proofImagePath: proofImagePath ?? request.proofImagePath,
              proofMessage: normalizedMessage?.isNotEmpty == true
                  ? normalizedMessage
                  : request.proofMessage,
              proofSavedAtIso: _now().toIso8601String(),
              cashbackEarned: cashbackEarned ?? request.cashbackEarned,
            );
          })
          .toList(growable: false);
      await _storage.writeRequestHistory(_requestHistory);
      _statusMessage = 'Proof saved locally for this transaction.';
    });
    return updated;
  }

  Future<void> removeRequest(String requestId) async {
    await removeRequests({requestId});
  }

  Future<void> removeRequests(Set<String> requestIds) async {
    if (requestIds.isEmpty) return;
    await _withSaving(() async {
      _requestHistory = _requestHistory
          .where((request) => !requestIds.contains(request.id))
          .toList(growable: false);
      await _storage.writeRequestHistory(_requestHistory);
      _statusMessage = requestIds.length == 1
          ? 'Transaction removed from history.'
          : '${requestIds.length} transactions removed from history.';
    });
  }

  PaymentRequestRecord? findRequestById(String requestId) {
    for (final record in _requestHistory) {
      if (record.id == requestId) {
        return record;
      }
    }
    return null;
  }

  Future<void> _withSaving(Future<void> Function() action) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
    } catch (error) {
      _errorMessage = '$error';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
