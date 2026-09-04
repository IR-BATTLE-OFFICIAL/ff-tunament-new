import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Starts a Razorpay order created by our server. Wallet crediting is never
/// done in the app: the server verifies Razorpay's signature first.
class PaymentService {
  PaymentService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;
  Razorpay? _razorpay;
  Completer<VerifiedPayment>? _paymentCompleter;

  Future<VerifiedPayment> startWalletTopUp({
    required int amountInPaise,
    required String userName,
    required String email,
    required String phone,
  }) async {
    if (amountInPaise < 500) {
      throw Exception('Minimum deposit amount is Rs. 5.');
    }

    final orderResult = await _functions
        .httpsCallable('createRazorpayOrder')
        .call<Map<String, dynamic>>({'amount': amountInPaise});
    final order = Map<String, dynamic>.from(orderResult.data);

    final orderId = order['orderId'] as String?;
    final keyId = order['keyId'] as String?;
    if (orderId == null || keyId == null) {
      throw Exception('Unable to create a secure payment order.');
    }

    _paymentCompleter = Completer<VerifiedPayment>();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);

    _razorpay!.open({
      'key': keyId,
      'order_id': orderId,
      'amount': amountInPaise,
      'currency': 'INR',
      'name': 'IR BATTLE',
      'description': 'Wallet top up',
      'prefill': {'name': userName, 'email': email, 'contact': phone},
      'method': {
        'upi': true,
      },
      'theme': {'color': '#D4FF00'},
    });

    return _paymentCompleter!.future;
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final verified = await _functions
          .httpsCallable('confirmRazorpayPayment')
          .call<Map<String, dynamic>>({
        'razorpayPaymentId': response.paymentId,
        'razorpayOrderId': response.orderId,
        'razorpaySignature': response.signature,
      });
      final data = Map<String, dynamic>.from(verified.data);
      _complete(VerifiedPayment(
        amountInPaise: data['amount'] as int,
        transactionId: data['transactionId'] as String,
      ));
    } on FirebaseFunctionsException catch (e) {
      _completeError(Exception(e.message ?? 'Payment verification failed.'));
    } catch (_) {
      _completeError(Exception('Payment verification failed. Please contact support.'));
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    _completeError(Exception(response.message ?? 'Payment was cancelled or failed.'));
  }

  void _onExternalWallet(ExternalWalletResponse response) {}

  void _complete(VerifiedPayment payment) {
    if (!(_paymentCompleter?.isCompleted ?? true)) _paymentCompleter!.complete(payment);
    dispose();
  }

  void _completeError(Object error) {
    if (!(_paymentCompleter?.isCompleted ?? true)) _paymentCompleter!.completeError(error);
    dispose();
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }
}

class VerifiedPayment {
  const VerifiedPayment({required this.amountInPaise, required this.transactionId});

  final int amountInPaise;
  final String transactionId;

  double get amount => amountInPaise / 100;
}
