// lib/models/payment_models.dart

class PaymentPlan {
  final String id;
  final String name;
  final double price;
  final String currency;
  final String duration;
  final List<String> features;
  final bool isPopular;

  const PaymentPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.duration,
    required this.features,
    this.isPopular = false,
  });

  static const List<PaymentPlan> availablePlans = [
    PaymentPlan(
      id: 'monthly_premium',
      name: 'Monthly Premium',
      price: 199.0,
      currency: 'INR',
      duration: 'month',
      features: [
        'Ad-free experience',
        'Offline content access',
        'Advanced analytics',
        'Priority support',
        'Unlimited guided sessions',
        'Premium meditation content',
      ],
    ),
    PaymentPlan(
      id: 'yearly_premium',
      name: 'Yearly Premium',
      price: 1999.0,
      currency: 'INR',
      duration: 'year',
      features: [
        'Ad-free experience',
        'Offline content access',
        'Advanced analytics',
        'Priority support',
        'Unlimited guided sessions',
        'Premium meditation content',
        '2 months free',
      ],
      isPopular: true,
    ),
  ];
}

class PaymentResult {
  final bool success;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? errorMessage;
  final String? errorCode;

  const PaymentResult({
    required this.success,
    this.paymentId,
    this.orderId,
    this.signature,
    this.errorMessage,
    this.errorCode,
  });

  factory PaymentResult.success({
    required String paymentId,
    required String orderId,
    required String signature,
  }) {
    return PaymentResult(
      success: true,
      paymentId: paymentId,
      orderId: orderId,
      signature: signature,
    );
  }

  factory PaymentResult.failure({
    required String errorMessage,
    String? errorCode,
  }) {
    return PaymentResult(
      success: false,
      errorMessage: errorMessage,
      errorCode: errorCode,
    );
  }
}
