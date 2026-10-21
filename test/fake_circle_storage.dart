import 'package:xeta_upi_circle_app/models/payment_request_record.dart';
import 'package:xeta_upi_circle_app/models/trusted_person.dart';
import 'package:xeta_upi_circle_app/services/circle_storage.dart';

class FakeCircleStorage implements CircleStorage {
  List<TrustedPerson> people = <TrustedPerson>[];
  List<PaymentRequestRecord> history = <PaymentRequestRecord>[];

  @override
  Future<List<TrustedPerson>> readTrustedPeople() async => people;

  @override
  Future<List<PaymentRequestRecord>> readRequestHistory() async => history;

  @override
  Future<void> writeRequestHistory(List<PaymentRequestRecord> requests) async {
    history = requests;
  }

  @override
  Future<void> writeTrustedPeople(List<TrustedPerson> nextPeople) async {
    people = nextPeople;
  }
}
