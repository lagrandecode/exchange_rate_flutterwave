import 'package:flutter/material.dart';

import '../models/country.dart';
import '../models/exchange_rate.dart';
import '../services/flutterwave_rate_service.dart';
import '../widgets/amount_field.dart';
import '../widgets/country_dropdown.dart';
import '../widgets/error_banner.dart';
import '../widgets/rate_result_card.dart';

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
  Country _destinationCountry = destinationCountries[14]; // Nigeria (NGN)
  
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
        const cacheKey = 'CAD_NGN';
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
  
  @override
  void dispose() {
    _amountController.dispose();
    _service.dispose();
    super.dispose();
  }

  void _updateRateFromCache() {
    final rawAmount = _amountController.text.trim();
    final amount = double.tryParse(rawAmount) ?? 1.0;
    
    // ignore: unnecessary_brace_in_string_interps
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
    // ignore: unnecessary_brace_in_string_interps
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
              AmountField(
                controller: _amountController,
                onChanged: _onAmountChanged,
              ),
              const SizedBox(height: 16),
              CountryDropdown(
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
              CountryDropdown(
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
                ErrorBanner(message: _error!),
              ] else if (_latestRate != null) ...[
                RateResultCard(rate: _latestRate!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

