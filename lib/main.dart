import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const ExchangeRateApp());
}

const _flutterwaveSecretKey = 'FLWSECK_TEST-77773752bc30f0a99af74caab64187d5-X';

class ExchangeRateApp extends StatelessWidget {
  const ExchangeRateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutterwave Exchange Rate',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const ExchangeRatePage(),
    );
  }
}

class ExchangeRatePage extends StatefulWidget {
  const ExchangeRatePage({super.key});

  @override
  State<ExchangeRatePage> createState() => _ExchangeRatePageState();
}

class _ExchangeRatePageState extends State<ExchangeRatePage> {
  final _amountController = TextEditingController(text: '1');
  final _service = FlutterwaveRateService();
  Timer? _debounce;
  DateTime? _lastFetchTime;
  final _currencies = const <String>[
    'NGN',
    'USD',
    'CAD',
    'GBP',
    'EUR',
    'KES',
    'GHS',
  ];

  String _sourceCurrency = 'NGN';
  String _destinationCurrency = 'CAD';
  ExchangeRate? _latestRate;
  String? _error;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _scheduleFetch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amountController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _fetchRate() async {
    final rawAmount = _amountController.text.trim();
    final amount = double.tryParse(rawAmount);
    if (amount == null || amount <= 0) {
      setState(() {
        _error = 'Enter a valid amount greater than zero.';
        _latestRate = null;
      });
      return;
    }

    final shouldSkipNetwork =
        _latestRate != null &&
        _latestRate!.matchesPair(
          sourceCurrency: _sourceCurrency,
          destinationCurrency: _destinationCurrency,
        ) &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) <
            const Duration(seconds: 45);

    if (shouldSkipNetwork) {
      setState(() {
        _latestRate = _latestRate!.copyWithSourceAmount(amount);
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rate = await _service.fetchRate(
        sourceAmount: amount,
        sourceCurrency: _sourceCurrency,
        destinationCurrency: _destinationCurrency,
      );

      setState(() {
        _latestRate = rate;
        _lastFetchTime = DateTime.now();
      });
    } on FlutterwaveException catch (e) {
      setState(() {
        _error = e.message;
        _latestRate = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _latestRate = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _scheduleFetch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      _fetchRate();
    });
  }

  void _onAmountChanged(String value) {
    final amount = double.tryParse(value);
    if (amount != null && amount > 0 && _latestRate != null) {
      setState(() {
        _latestRate = _latestRate!.copyWithSourceAmount(amount);
      });
    }
    _scheduleFetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutterwave Exchange Rate'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _fetchRate,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh rate',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Check real-time transfer rates using the Flutterwave API.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              _AmountField(
                controller: _amountController,
                onChanged: _onAmountChanged,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _CurrencyDropdown(
                      label: 'From',
                      value: _sourceCurrency,
                      options: _currencies,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _sourceCurrency = value);
                          _lastFetchTime = null;
                          _scheduleFetch();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _CurrencyDropdown(
                      label: 'To',
                      value: _destinationCurrency,
                      options: _currencies,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _destinationCurrency = value);
                          _lastFetchTime = null;
                          _scheduleFetch();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isLoading
                    ? const LinearProgressIndicator(key: ValueKey('loading'))
                    : const SizedBox(key: ValueKey('idle'), height: 4),
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                _ErrorBanner(message: _error!),
              ] else if (_latestRate != null) ...[
                _RateResultCard(rate: _latestRate!),
              ] else ...[
                const _PlaceholderCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: false,
      ),
      decoration: const InputDecoration(
        labelText: 'Amount',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.currency_exchange),
        helperText: 'Enter the amount you plan to send (source currency).',
      ),
      onChanged: onChanged,
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  const _CurrencyDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      items: options
          .map(
            (currency) => DropdownMenuItem<String>(
              value: currency,
              child: Text(currency),
            ),
          )
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _RateResultCard extends StatelessWidget {
  const _RateResultCard({required this.rate});

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
            const SizedBox(height: 8),
            Text(
              'Effective rate: ${rate.effectiveRate.toStringAsFixed(4)} ${rate.sourceCurrency}/${rate.destinationCurrency}',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No rate fetched yet', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Enter an amount, choose currencies, and tap "Get Rate" to see the latest transfer rate.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FlutterwaveRateService {
  FlutterwaveRateService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  static const _baseUrl = 'https://api.flutterwave.com/v3';

  Future<ExchangeRate> fetchRate({
    required double sourceAmount,
    required String sourceCurrency,
    required String destinationCurrency,
  }) async {
    final uri = Uri.parse('$_baseUrl/transfers/rates').replace(
      queryParameters: <String, String>{
        'amount': '1',
        'source_currency': sourceCurrency,
        'destination_currency': destinationCurrency,
      },
    );

    final response = await _client.get(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer $_flutterwaveSecretKey',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      final status = jsonBody['status'] as String?;
      if (status == 'success') {
        final data = jsonBody['data'] as Map<String, dynamic>?;
        if (data == null) {
          throw const FlutterwaveException('Missing rate data in response.');
        }
        return ExchangeRate.fromApi(
          data: data,
          sourceAmount: sourceAmount,
          fallbackSourceCurrency: sourceCurrency,
          fallbackDestinationCurrency: destinationCurrency,
        );
      }
      final message = jsonBody['message'] as String?;
      throw FlutterwaveException(message ?? 'Failed to fetch rate.');
    } else {
      throw FlutterwaveException(
        'Request failed with status code ${response.statusCode}.',
      );
    }
  }

  void dispose() {
    _client.close();
  }
}

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
    if (sourceCurrency == 'NGN' && destinationCurrency != 'NGN') {
      return '1 $destinationCurrency = ${rate.toStringAsFixed(precision)} $sourceCurrency';
    }
    if (destinationCurrency == 'NGN' && sourceCurrency != 'NGN') {
      final inverse = rate == 0 ? 0 : 1 / rate;
      return '1 $sourceCurrency = ${inverse.toStringAsFixed(precision)} $destinationCurrency';
    }
    return '1 $destinationCurrency = ${rate.toStringAsFixed(precision)} $sourceCurrency';
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
