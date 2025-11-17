import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const ExchangeRateApp());
}

const _flutterwaveSecretKey = 'FLWSECK_TEST-77773752bc30f0a99af74caab64187d5-X';

// Country data model
class Country {
  final String name;
  final String currencyCode;
  final String countryCode; // ISO 3166-1 alpha-2 code for flag

  const Country({
    required this.name,
    required this.currencyCode,
    required this.countryCode,
  });

  String get flagUrl => 'https://flagcdn.com/w40/${countryCode.toLowerCase()}.png';
}

// Source currencies (From)
final List<Country> sourceCountries = const [
  Country(name: 'United States', currencyCode: 'USD', countryCode: 'US'),
  Country(name: 'Canada', currencyCode: 'CAD', countryCode: 'CA'),
  Country(name: 'United Kingdom', currencyCode: 'GBP', countryCode: 'GB'),
  Country(name: 'Eurozone', currencyCode: 'EUR', countryCode: 'EU'),
];

// Destination countries (To) - African countries
final List<Country> destinationCountries = const [
  Country(name: 'Benin', currencyCode: 'XOF', countryCode: 'BJ'),
  Country(name: 'Burkina Faso', currencyCode: 'XOF', countryCode: 'BF'),
  Country(name: 'Cameroon', currencyCode: 'XAF', countryCode: 'CM'),
  Country(name: 'Central African Republic', currencyCode: 'XAF', countryCode: 'CF'),
  Country(name: 'Chad', currencyCode: 'XAF', countryCode: 'TD'),
  Country(name: 'Egypt', currencyCode: 'EGP', countryCode: 'EG'),
  Country(name: 'Equatorial Guinea', currencyCode: 'XAF', countryCode: 'GQ'),
  Country(name: 'Ethiopia', currencyCode: 'ETB', countryCode: 'ET'),
  Country(name: 'Gabon', currencyCode: 'XAF', countryCode: 'GA'),
  Country(name: 'Ghana', currencyCode: 'GHS', countryCode: 'GH'),
  Country(name: 'Guinea Bissau', currencyCode: 'XOF', countryCode: 'GW'),
  Country(name: 'Kenya', currencyCode: 'KES', countryCode: 'KE'),
  Country(name: 'Mali', currencyCode: 'XOF', countryCode: 'ML'),
  Country(name: 'Morocco', currencyCode: 'MAD', countryCode: 'MA'),
  Country(name: 'Nigeria', currencyCode: 'NGN', countryCode: 'NG'),
  Country(name: 'Rep. Congo', currencyCode: 'XAF', countryCode: 'CG'),
  Country(name: 'Senegal', currencyCode: 'XOF', countryCode: 'SN'),
  Country(name: 'South Africa', currencyCode: 'ZAR', countryCode: 'ZA'),
  Country(name: 'Togo', currencyCode: 'XOF', countryCode: 'TG'),
  Country(name: 'Uganda', currencyCode: 'UGX', countryCode: 'UG'),
  Country(name: 'Zambia', currencyCode: 'ZMW', countryCode: 'ZM'),
];

class ExchangeRateApp extends StatelessWidget {
  const ExchangeRateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutterwave Exchange Rate',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
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

  Country _sourceCountry = sourceCountries[1]; // CAD (default)
  Country _destinationCountry = destinationCountries[17]; // Nigeria (NGN)
  
  String get _sourceCurrency => _sourceCountry.currencyCode;
  String get _destinationCurrency => _destinationCountry.currencyCode;
  ExchangeRate? _latestRate;
  String? _error;
  
  // Store all rates in memory for instant access
  final Map<String, ExchangeRate> _ratesCache = {};

  @override
  void initState() {
    super.initState();
    // IMMEDIATELY fetch default rate (CAD->NGN) via HTTP for instant display
    _fetchDefaultRateInstantly();
    
    // Connect to WebSocket for real-time updates (in background)
    _service.connect();
    // Listen to WebSocket messages
    _service.onAllRatesReceived = (rates) {
      if (mounted) {
        setState(() {
          _ratesCache.clear();
          _ratesCache.addAll(rates);
        });
        _updateRateFromCache();
      }
    };
    _service.onRateUpdate = (key, rate) {
      if (mounted) {
        setState(() {
          _ratesCache[key] = rate;
        });
        _updateRateFromCache();
      }
    };
    
    // Load all rates in background (for instant currency switching)
    _loadAllRatesInBackground();
  }
  
  Future<void> _fetchDefaultRateInstantly() async {
    // Fetch CAD->NGN immediately via HTTP (fast, from database)
    try {
      final rate = await _service.fetchRate(
        sourceAmount: 1.0,
        sourceCurrency: 'CAD',
        destinationCurrency: 'NGN',
      );
      if (mounted) {
        final cacheKey = 'CAD_NGN';
        setState(() {
          _latestRate = rate;
          _ratesCache[cacheKey] = rate;
          _error = null;
        });
      }
    } catch (e) {
      // Silently fail - will try again or use WebSocket data
    }
  }
  
  Future<void> _loadAllRatesInBackground() async {
    // Load all rates in background for instant currency switching
    try {
      final allRates = await _service.fetchAllRates(baseCurrency: _sourceCurrency);
      if (mounted) {
        setState(() {
          _ratesCache.addAll(allRates);
        });
        _updateRateFromCache();
      }
    } catch (e) {
      // Silently fail - WebSocket will provide updates
    }
  }
  
  Future<void> _loadAllRates() async {
    // Alias for consistency
    _loadAllRatesInBackground();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _service.dispose();
    super.dispose();
  }

  void _updateRateFromCache() {
    final rawAmount = _amountController.text.trim();
    final amount = double.tryParse(rawAmount) ?? 1.0;
    
    final cacheKey = '${_sourceCurrency}_${_destinationCurrency}';
    final cachedRate = _ratesCache[cacheKey];
    
    if (cachedRate != null) {
      setState(() {
        _latestRate = cachedRate.copyWithSourceAmount(amount);
        _error = null;
      });
    } else {
      // Rate not in cache - fetch it immediately (especially for GHS)
      _fetchRateIfNotInCache();
    }
  }
  
  Future<void> _fetchRateIfNotInCache() async {
    final cacheKey = '${_sourceCurrency}_${_destinationCurrency}';
    if (_ratesCache.containsKey(cacheKey)) {
      return; // Already in cache or being fetched
    }
    
    try {
      final rate = await _service.fetchRate(
        sourceAmount: 1.0,
        sourceCurrency: _sourceCurrency,
        destinationCurrency: _destinationCurrency,
      );
      if (mounted) {
        setState(() {
          _ratesCache[cacheKey] = rate;
          _latestRate = rate.copyWithSourceAmount(double.tryParse(_amountController.text.trim()) ?? 1.0);
          _error = null;
        });
      }
    } catch (e) {
      // Silently fail - will be loaded by background fetch or WebSocket
    }
  }

  void _onAmountChanged(String value) {
    // Instantly update rate from cache when amount changes
    _updateRateFromCache();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutterwave Exchange Rate'),
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
              _CountryDropdown(
                label: 'From',
                value: _sourceCountry,
                countries: sourceCountries,
                onChanged: (country) {
                  if (country != null) {
                    setState(() => _sourceCountry = country);
                    // Instantly show from cache - no loading
                    _updateRateFromCache();
                    // Load all rates for new base currency in background
                    _loadAllRatesInBackground();
                  }
                },
              ),
              const SizedBox(height: 16),
              _CountryDropdown(
                label: 'To',
                value: _destinationCountry,
                countries: destinationCountries,
                onChanged: (country) {
                  if (country != null) {
                    setState(() => _destinationCountry = country);
                    // Instantly show from cache - no loading
                    _updateRateFromCache();
                  }
                },
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                _ErrorBanner(message: _error!),
              ] else if (_latestRate != null) ...[
                _RateResultCard(rate: _latestRate!),
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

class _CountryDropdown extends StatelessWidget {
  const _CountryDropdown({
    required this.label,
    required this.value,
    required this.countries,
    required this.onChanged,
  });

  final String label;
  final Country value;
  final List<Country> countries;
  final ValueChanged<Country?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Country>(
      value: value,
      items: countries
          .map(
            (country) => DropdownMenuItem<Country>(
              value: country,
              child: SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    Image.network(
                      country.flagUrl,
                      width: 24,
                      height: 18,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(
                        width: 24,
                        height: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        country.name,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        country.currencyCode,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      selectedItemBuilder: (context) {
        return countries.map((country) {
          return Text(
            '${country.name} (${country.currencyCode})',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          );
        }).toList();
      },
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
            // Text(
            //   'Effective rate: ${rate.effectiveRate.toStringAsFixed(4)} ${rate.sourceCurrency}/${rate.destinationCurrency}',
            //   style: textTheme.bodyMedium,
            // ),
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
  // For iOS Simulator/Android Emulator: use 'ws://localhost:8000'
  // For physical device: use your Mac's IP, e.g., 'ws://10.0.0.27:8000'
  static const _backendBaseUrl = 'http://localhost:8000';
  static const _backendWsUrl = 'ws://localhost:8000';
  static const bool _useBackend = true;
  
  WebSocketChannel? _channel;
  Function(Map<String, ExchangeRate>)? onAllRatesReceived;
  Function(String, ExchangeRate)? onRateUpdate;

  Future<ExchangeRate> fetchRate({
    required double sourceAmount,
    required String sourceCurrency,
    required String destinationCurrency,
  }) async {
    final Map<String, String> query = <String, String>{
      'amount': '1',
      'source_currency': sourceCurrency,
      'destination_currency': destinationCurrency,
    };

    final uri = _useBackend
        ? Uri.parse('$_backendBaseUrl/api/rates/').replace(queryParameters: query)
        : Uri.parse('$_baseUrl/transfers/rates').replace(queryParameters: query);

    final headers = _useBackend
        ? <String, String>{'Content-Type': 'application/json'}
        : <String, String>{
            'Authorization': 'Bearer $_flutterwaveSecretKey',
            'Content-Type': 'application/json',
          };

    final response = await _client.get(uri, headers: headers);

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

  Future<Map<String, ExchangeRate>> fetchAllRates({
    required String baseCurrency,
  }) async {
    if (!_useBackend) {
      throw const FlutterwaveException('All rates endpoint only available via backend');
    }

    final uri = Uri.parse('$_backendBaseUrl/api/rates/all/')
        .replace(queryParameters: {'base_currency': baseCurrency});

    final response = await _client.get(
      uri,
      headers: <String, String>{'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      final status = jsonBody['status'] as String?;
      if (status == 'success') {
        final data = jsonBody['data'] as Map<String, dynamic>?;
        if (data == null) {
          throw const FlutterwaveException('Missing rates data in response.');
        }

        final Map<String, ExchangeRate> rates = {};
        data.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            try {
              // Parse the key (e.g., "NGN_CAD") to get currencies
              final parts = key.split('_');
              if (parts.length == 2) {
                // The value is already the Flutterwave response shape
                final rateData = value['data'] as Map<String, dynamic>? ?? value;
                final rate = ExchangeRate.fromApi(
                  data: rateData,
                  sourceAmount: 1.0,
                  fallbackSourceCurrency: parts[0],
                  fallbackDestinationCurrency: parts[1],
                );
                rates[key] = rate;
              }
            } catch (e) {
              // Skip invalid entries
            }
          }
        });
        return rates;
      }
      final message = jsonBody['message'] as String?;
      throw FlutterwaveException(message ?? 'Failed to fetch all rates.');
    } else {
      throw FlutterwaveException(
        'Request failed with status code ${response.statusCode}.',
      );
    }
  }

  void connect() {
    if (_channel != null) return; // Already connected
    
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$_backendWsUrl/ws/rates/'),
      );
      
      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message) as Map<String, dynamic>;
            final type = data['type'] as String?;
            
            if (type == 'all_rates') {
              final ratesData = data['data'] as Map<String, dynamic>?;
              if (ratesData != null) {
                final Map<String, ExchangeRate> rates = {};
                ratesData.forEach((key, value) {
                  if (value is Map<String, dynamic>) {
                    try {
                      final parts = key.split('_');
                      if (parts.length == 2) {
                        final rateData = value['data'] as Map<String, dynamic>? ?? value;
                        final rate = ExchangeRate.fromApi(
                          data: rateData,
                          sourceAmount: 1.0,
                          fallbackSourceCurrency: parts[0],
                          fallbackDestinationCurrency: parts[1],
                        );
                        rates[key] = rate;
                      }
                    } catch (e) {
                      // Skip invalid entries
                    }
                  }
                });
                onAllRatesReceived?.call(rates);
              }
            } else if (type == 'rate_update') {
              final updateData = data['data'] as Map<String, dynamic>?;
              if (updateData != null) {
                final key = updateData['key'] as String?;
                final rateData = updateData['rate'] as Map<String, dynamic>?;
                if (key != null && rateData != null) {
                  try {
                    final parts = key.split('_');
                    if (parts.length == 2) {
                      final rate = ExchangeRate.fromApi(
                        data: rateData['data'] as Map<String, dynamic>? ?? rateData,
                        sourceAmount: 1.0,
                        fallbackSourceCurrency: parts[0],
                        fallbackDestinationCurrency: parts[1],
                      );
                      onRateUpdate?.call(key, rate);
                    }
                  } catch (e) {
                    // Skip invalid updates
                  }
                }
              }
            } else if (type == 'all_rates_update') {
              // Server indicates all rates have been updated, request fresh data
              requestAllRates();
            }
          } catch (e) {
            // Ignore parse errors
          }
        },
        onError: (error) {
          // Reconnect on error
          _channel = null;
          Future.delayed(const Duration(seconds: 5), () {
            if (_channel == null) {
              connect();
            }
          });
        },
        onDone: () {
          // Reconnect when connection closes
          _channel = null;
          Future.delayed(const Duration(seconds: 5), () {
            if (_channel == null) {
              connect();
            }
          });
        },
      );
    } catch (e) {
      // Connection failed, will retry
      _channel = null;
    }
  }
  
  void requestAllRates() {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({'type': 'get_all_rates'}));
    }
  }

  void dispose() {
    _channel?.sink.close();
    _channel = null;
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

