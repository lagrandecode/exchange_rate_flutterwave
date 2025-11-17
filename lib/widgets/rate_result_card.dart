import 'package:flutter/material.dart';

import '../models/exchange_rate.dart';

class RateResultCard extends StatelessWidget {
  const RateResultCard({super.key, required this.rate});

  final ExchangeRate rate;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exchange Rate',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(rate.formattedRateText, style: textTheme.headlineSmall),
            const Divider(height: 32),
            Text(
              'You send: ${rate.sourceAmount.toStringAsFixed(2)} ${rate.sourceCurrency}',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Recipient gets: ${rate.destinationAmount.toStringAsFixed(2)} ${rate.destinationCurrency}',
              style: textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

