import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/exchange_rate.dart';

const _flutterwaveSecretKey = 'FLWSECK_TEST-77773752bc30f0a99af74caab64187d5-X';

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

