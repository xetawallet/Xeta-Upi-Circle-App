import 'package:flutter_test/flutter_test.dart';
import 'package:xeta_upi_circle_app/controllers/xeta_upi_circle_app_controller.dart';
import 'package:xeta_upi_circle_app/models/payment_request_record.dart';
import 'package:xeta_upi_circle_app/models/trusted_person.dart';

import 'fake_circle_storage.dart';

void main() {
  group('XetaUpiCircleAppController', () {
    late FakeCircleStorage storage;
    late XetaUpiCircleAppController controller;

    setUp(() {
      storage = FakeCircleStorage();
      controller = XetaUpiCircleAppController(storage: storage);
    });

    tearDown(() {
      controller.dispose();
    });

    test('adds trusted person and selects them', () async {
      await controller.initialize();
      await controller.saveTrustedPerson(
        const TrustedPerson(id: '1', name: 'Riya', phoneNumber: '9876543210'),
      );

      expect(controller.trustedPeople.length, 1);
      expect(controller.selectedHelper?.name, 'Riya');
    });

    test('creates draft from UPI id', () async {
      await controller.initialize();
      controller.createDraftFromInput(
        rawInput: 'merchant@upi',
        amountText: '250',
        noteText: 'Cafe bill',
      );

      expect(controller.currentDraft?.upiId, 'merchant@upi');
      expect(controller.currentDraft?.amount, '250');
      expect(controller.currentDraft?.note, 'Cafe bill');
    });

    test('records request after helper and draft exist', () async {
      await controller.initialize();
      await controller.saveTrustedPerson(
        const TrustedPerson(id: '1', name: 'Arjun', phoneNumber: '9876543210'),
      );
      controller.createDraftFromInput(rawInput: 'shop@upi');

      await controller.recordSentRequestWithId(
        channel: 'WhatsApp',
        requestId: 'request-1',
      );

      expect(controller.requestHistory.length, 1);
      expect(controller.requestHistory.first.helper.name, 'Arjun');
      expect(controller.requestHistory.first.channel, 'WhatsApp');
      expect(controller.requestHistory.first.id, 'request-1');
    });

    test('builds WhatsApp message for local proof saving later', () async {
      await controller.initialize();
      await controller.saveTrustedPerson(
        const TrustedPerson(
          id: '1',
          name: 'Maya',
          phoneNumber: '9876543210',
          upiId: '',
        ),
      );
      controller.createDraftFromInput(
        rawInput: 'upi://pay?pa=merchant@upi&pn=Coffee%20Shop&am=20',
      );

      final message = controller.buildRequestMessage();

      expect(
        message,
        contains(
          'I will save the transaction proof later inside Xeta UPI Circle App.',
        ),
      );
      expect(message, contains('Pay To: Coffee Shop'));
      expect(message, contains('UPI ID: merchant@upi'));
      expect(message, contains('Amount: Rs 20'));
      expect(message, contains('QR Code: attached image'));
      expect(message, isNot(contains('Reference ID:')));
    });

    test('saves proof details for a transaction', () async {
      await controller.initialize();
      await controller.saveTrustedPerson(
        const TrustedPerson(id: '1', name: 'Arjun', phoneNumber: '9876543210'),
      );
      controller.createDraftFromInput(rawInput: 'shop@upi');
      await controller.recordSentRequestWithId(
        channel: 'WhatsApp',
        requestId: 'request-2',
      );

      final updated = await controller.saveProofForRequest(
        requestId: 'request-2',
        proofImagePath: '/tmp/proof.png',
        proofMessage: 'Paid on WhatsApp',
      );

      expect(updated, isTrue);
      expect(controller.requestHistory.first.status, RequestStatus.proofSaved);
      expect(controller.requestHistory.first.proofImagePath, '/tmp/proof.png');
      expect(controller.requestHistory.first.proofMessage, 'Paid on WhatsApp');
      expect(controller.requestHistory.first.proofSavedAtIso, isNotNull);
    });
  });
}
