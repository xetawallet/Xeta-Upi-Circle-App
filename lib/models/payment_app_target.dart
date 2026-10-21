import 'request_draft.dart';

enum PaymentAppTarget { paytm, superMoney }

extension PaymentAppTargetX on PaymentAppTarget {
  String get label {
    switch (this) {
      case PaymentAppTarget.paytm:
        return 'Paytm';
      case PaymentAppTarget.superMoney:
        return 'SuperMoney';
    }
  }

  String get packageName {
    switch (this) {
      case PaymentAppTarget.paytm:
        return 'net.one97.paytm';
      case PaymentAppTarget.superMoney:
        return 'money.super.payments';
    }
  }

  String get storageValue {
    switch (this) {
      case PaymentAppTarget.paytm:
        return 'paytm';
      case PaymentAppTarget.superMoney:
        return 'super_money';
    }
  }

  String buildTargetedIntent(RequestDraft draft) {
    return 'intent://pay?${draft.intentQuery}#Intent;scheme=upi;package=$packageName;end';
  }

  static PaymentAppTarget fromStorageValue(String? value) {
    switch (value) {
      case 'super_money':
        return PaymentAppTarget.superMoney;
      case 'paytm':
      default:
        return PaymentAppTarget.paytm;
    }
  }
}
