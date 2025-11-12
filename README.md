# Flutterwave Exchange Rate Demo

This Flutter app shows how to retrieve and display transfer rates from the Flutterwave `/v3/transfers/rates` API. Users can pick a source and destination currency, enter the amount they plan to send, and see the equivalent amount the receiver should get along with the effective exchange rate.

https://github.com/olayomid1/exchange_rate_flutterwave/assets/59301241/c51a6fac-d9a5-49f5-ac40-d19a5d5598ce

## Features

- Auto-fetch of rates (debounced) as the user types or changes currencies.
- Real-time update of the displayed amount while the rate call completes in the background.
- Friendly error handling and retry via the app bar refresh icon.
- Inline formatting showing rates like `1 CAD = 1109.7276 NGN`.

## Prerequisites

- Flutter SDK (3.22+ recommended).
- A Flutterwave **Secret Key** with access to the test or live environment.

## Getting Started

1. **Clone the repo**
   ```sh
   git clone https://github.com/olayomid1/exchange_rate_flutterwave.git
   cd exchange_rate_flutterwave
   ```

2. **Install dependencies**
   ```sh
   flutter pub get
   ```

3. **Configure the Flutterwave key**
   - The demo uses a hard-coded test key (`lib/main.dart`, `_flutterwaveSecretKey`).  
     Replace it with your own key or load it securely (e.g., `--dart-define`, secrets manager) for production.

4. **Run the app**
   ```sh
   flutter run
   ```

## How It Works

The UI is powered by `lib/main.dart`. `FlutterwaveRateService` wraps the `/transfers/rates` endpoint. When the user updates the amount or currencies:

1. Input is debounced for 350 ms to avoid spamming the API.
2. The app sends a request with `amount=1` to get a per-unit rate, matching Flutterwave's response format.
3. The cached rate is reused to instantly recalculate amounts while a fresh request is made (unless the corridor or cache age forces a new call).

### Example API Response

```json
{
  "status": "success",
  "message": "Transfer amount fetched",
  "data": {
    "rate": 1109.727585,
    "source": {
      "currency": "NGN",
      "amount": 1109.727585
    },
    "destination": {
      "currency": "CAD",
      "amount": 1
    }
  }
}
```

The rate is then applied to the user's amount to render:

- `You send: 1109.73 NGN`
- `Recipient gets: 1.00 CAD`
- `Effective rate: 1109.73 NGN/CAD`

## Notes & Next Steps

- For "instant" updates like TapTap Money, consider adding a backend cache that polls the rates and serves them from memory rather than hitting Flutterwave on every interaction.
- Move API keys out of source control before shipping.
- Add tests or widget tests if you plan to extend the project.

## License

MIT License (c) 2025 Oluwaseun A. (update as needed)

