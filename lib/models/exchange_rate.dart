class ExchangeRate {
  ExchangeRate({
    required this.rate,
    required this.sourceCurrency,
    required this.sourceAmount,
    required this.destinationCurrency,
    required this.destinationAmount,
  });

  factory ExchangeRate.fromApi({
    required Map<String, dynamic> data,
    required double sourceAmount,
    required String fallbackSourceCurrency,
    required String fallbackDestinationCurrency,
  }) {
    final rateValue = (data['rate'] as num?)?.toDouble();
    if (rateValue == null || rateValue <= 0) {
      throw const FlutterwaveException('Exchange rate not found in response.');
    }

    final sourceMeta =
        data['source'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final destinationMeta =
        data['destination'] as Map<String, dynamic>? ?? <String, dynamic>{};

    final sourceCurrency =
        sourceMeta['currency'] as String? ?? fallbackSourceCurrency;
    final destinationCurrency =
        destinationMeta['currency'] as String? ?? fallbackDestinationCurrency;

    final destinationAmount = sourceAmount / rateValue;

    return ExchangeRate(
      rate: rateValue,
      sourceCurrency: sourceCurrency,
      sourceAmount: sourceAmount,
      destinationCurrency: destinationCurrency,
      destinationAmount: destinationAmount,
    );
  }

  final double rate;
  final String sourceCurrency;
  final double sourceAmount;
  final String destinationCurrency;
  final double destinationAmount;

  double get effectiveRate =>
      destinationAmount == 0 ? 0 : sourceAmount / destinationAmount;

  String get formattedRateText {
    const precision = 4;
    // Always show "from = to" format: 1 [source] = X [destination]
    final inverse = rate == 0 ? 0 : 1 / rate;
    return '1 $sourceCurrency = ${inverse.toStringAsFixed(precision)} $destinationCurrency';
  }

  ExchangeRate copyWithSourceAmount(double newSourceAmount) {
    final newDestinationAmount = newSourceAmount <= 0
        ? 0.0
        : newSourceAmount / rate;
    return ExchangeRate(
      rate: rate,
      sourceCurrency: sourceCurrency,
      sourceAmount: newSourceAmount,
      destinationCurrency: destinationCurrency,
      destinationAmount: newDestinationAmount,
    );
  }

  bool matchesPair({
    required String sourceCurrency,
    required String destinationCurrency,
  }) {
    return sourceCurrency.toUpperCase() == this.sourceCurrency.toUpperCase() &&
        destinationCurrency.toUpperCase() ==
            this.destinationCurrency.toUpperCase();
  }
}

class FlutterwaveException implements Exception {
  const FlutterwaveException(this.message);

  final String message;

  @override
  String toString() => 'FlutterwaveException: $message';
}

