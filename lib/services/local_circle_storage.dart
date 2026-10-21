import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/payment_request_record.dart';
import '../models/trusted_person.dart';
import 'circle_storage.dart';

class LocalCircleStorage implements CircleStorage {
  static const _trustedPeopleKey = 'trusted_people_v1';
  static const _requestHistoryKey = 'request_history_v1';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<List<TrustedPerson>> readTrustedPeople() async {
    final rawJson = await _preferences.getString(_trustedPeopleKey);
    if (rawJson == null || rawJson.isEmpty) {
      return const <TrustedPerson>[];
    }

    final decoded = jsonDecode(rawJson) as List<dynamic>;
    return decoded
        .map(
          (item) =>
              TrustedPerson.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  @override
  Future<void> writeTrustedPeople(List<TrustedPerson> people) async {
    final encoded = jsonEncode(
      people.map((person) => person.toJson()).toList(growable: false),
    );
    await _preferences.setString(_trustedPeopleKey, encoded);
  }

  @override
  Future<List<PaymentRequestRecord>> readRequestHistory() async {
    final rawJson = await _preferences.getString(_requestHistoryKey);
    if (rawJson == null || rawJson.isEmpty) {
      return const <PaymentRequestRecord>[];
    }

    final decoded = jsonDecode(rawJson) as List<dynamic>;
    return decoded
        .map(
          (item) => PaymentRequestRecord.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> writeRequestHistory(List<PaymentRequestRecord> requests) async {
    final encoded = jsonEncode(
      requests.map((request) => request.toJson()).toList(growable: false),
    );
    await _preferences.setString(_requestHistoryKey, encoded);
  }
}
