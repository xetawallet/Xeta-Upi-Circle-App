import '../models/payment_request_record.dart';
import '../models/trusted_person.dart';

abstract class CircleStorage {
  Future<List<TrustedPerson>> readTrustedPeople();

  Future<void> writeTrustedPeople(List<TrustedPerson> people);

  Future<List<PaymentRequestRecord>> readRequestHistory();

  Future<void> writeRequestHistory(List<PaymentRequestRecord> requests);
}
