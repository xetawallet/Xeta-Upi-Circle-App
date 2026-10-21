import '../models/request_draft.dart';

class UpiParser {
  const UpiParser();

  RequestDraft parse({
    required String rawInput,
    String? amountText,
    String? noteText,
  }) {
    final input = rawInput.trim();
    if (input.isEmpty) {
      throw const FormatException(
        'Enter a UPI ID or scan a valid UPI QR code.',
      );
    }

    final normalizedAmount = _cleanOptionalValue(amountText);
    final normalizedNote = _cleanOptionalValue(noteText);

    if (input.toLowerCase().startsWith('upi://pay')) {
      final uri = Uri.parse(input);
      final query = uri.queryParameters;

      return RequestDraft(
        rawValue: input,
        sourceLabel: 'Scanned QR',
        upiId: _cleanOptionalValue(query['pa']),
        payeeName: _cleanOptionalValue(query['pn']),
        amount: normalizedAmount ?? _cleanOptionalValue(query['am']),
        note: normalizedNote ?? _cleanOptionalValue(query['tn']),
        mc: _cleanOptionalValue(query['mc']),
        cu: _cleanOptionalValue(query['cu']),
      );
    }

    if (_looksLikeUpiId(input)) {
      return RequestDraft(
        rawValue: input,
        sourceLabel: 'Manual UPI ID',
        upiId: input,
        amount: normalizedAmount,
        note: normalizedNote,
      );
    }

    throw const FormatException(
      'That does not look like a UPI ID or a UPI QR payload.',
    );
  }

  bool _looksLikeUpiId(String value) {
    final pattern = RegExp(r'^[a-zA-Z0-9.\-_]{2,}@[a-zA-Z]{2,}$');
    return pattern.hasMatch(value);
  }

  String? _cleanOptionalValue(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
