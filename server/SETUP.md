# Django Backend Setup - Real-Time WebSocket Rate Updates

This backend implements a real-time rate system with WebSocket support:
1. All rates are pre-fetched from Flutterwave and stored in the database
2. Django serves rates from the database (instant response)
3. Background job refreshes rates every 10 minutes
4. **WebSocket broadcasts real-time updates** to all connected clients instantly

## Setup Steps

### 1. Install Dependencies

```bash
cd server
source .venv/bin/activate
pip install -r requirements.txt
```

### 2. Create Database Tables

```bash
python manage.py makemigrations
python manage.py migrate
```

### 3. Initial Rate Fetch

Run the poller command once to populate the database with initial rates:

```bash
python manage.py poll_rates --once
```

This will fetch all currency pairs (4 source × 15 destination = 60 pairs) and store them in the database.

### 4. Start Background Rate Fetcher

Run the poller in a separate terminal to keep rates updated every 10 minutes:

```bash
python manage.py poll_rates
```

Or use `--once` flag with a cron job:

```bash
# Add to crontab (runs every 10 minutes)
*/10 * * * * cd /path/to/server && source .venv/bin/activate && python manage.py poll_rates --once
```

### 5. Start Django Server (with WebSocket support)

**Important**: Use `daphne` or `uvicorn` instead of `runserver` for WebSocket support:

```bash
# Install daphne if not already installed
pip install daphne

# Start server with WebSocket support
daphne -b 0.0.0.0 -p 8000 backend.asgi:application
```

Or using uvicorn:
```bash
pip install uvicorn[standard]
uvicorn backend.asgi:application --host 0.0.0.0 --port 8000
```

**Note**: The regular `runserver` command does NOT support WebSockets. You must use `daphne` or `uvicorn`.

## How It Works

1. **Background Job**: `poll_rates` command fetches all rates from Flutterwave every 10 minutes and stores them in the database
2. **WebSocket Broadcasting**: When rates are updated, they're instantly broadcast to all connected Flutter clients via WebSocket
3. **API Endpoints**: 
   - `/api/rates/?source_currency=USD&destination_currency=NGN` - Get single rate (from DB)
   - `/api/rates/all/?base_currency=USD` - Get all rates for a base currency (from DB)
   - `ws://localhost:8000/ws/rates/` - WebSocket endpoint for real-time updates
4. **Flutter App**: 
   - Connects to WebSocket on app load
   - Receives all rates instantly on connection
   - Gets real-time updates when rates change (no polling needed!)

## Benefits

- **Instant Response**: Rates served from database (no waiting for Flutterwave API)
- **Real-Time Updates**: WebSocket pushes updates instantly to all clients (no polling!)
- **Always Fresh**: Rates updated every 10 minutes automatically
- **No Loading Spinners**: All rates pre-loaded, instant currency switching
- **Scalable**: Database + WebSocket can handle many concurrent requests
- **Efficient**: No HTTP polling overhead - updates pushed only when rates change

