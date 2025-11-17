# Exchange Rate Backend (Django + Redis)

Low-latency exchange-rate cache that polls Flutterwave and serves the app instantly.

## Features
- Caches rates in Redis for fast reads
- Polls Flutterwave periodically to keep cache warm
- Serves rates via `/api/rates/` with the same JSON shape as Flutterwave
- CORS enabled for local Flutter dev

## Quickstart
1. Create and activate a virtualenv (Python 3.10+ recommended)
2. Install requirements:
   ```bash
   pip install -r requirements.txt
   ```
3. Copy env:
   ```bash
   cp .env.example .env
   # edit .env and set FLUTTERWAVE_SECRET_KEY and REDIS_URL
   ```
4. Run Redis locally (default: `redis://localhost:6379/1`)
5. Run dev server:
   ```bash
   python manage.py migrate
   python manage.py runserver 0.0.0.0:8000
   ```
6. (Optional) Start poller for live corridors:
   ```bash
   # polls every 30s by default
   python manage.py poll_rates --interval 30
   ```

## Endpoint
GET `/api/rates/?source_currency=NGN&destination_currency=CAD&amount=1`

Response (same as Flutterwave):
```json
{
  "status": "success",
  "message": "Transfer amount fetched",
  "data": {
    "rate": 1109.727585,
    "source": { "currency": "NGN", "amount": 1109.727585 },
    "destination": { "currency": "CAD", "amount": 1 }
  }
}
```

## Notes
- For production, run under gunicorn/uvicorn behind Nginx and secure the endpoint.
***

