#!/bin/bash
cd "$(dirname "$0")"
source .venv/bin/activate
echo "Starting Django server with WebSocket support on port 8000..."
daphne -b 0.0.0.0 -p 8000 backend.asgi:application

