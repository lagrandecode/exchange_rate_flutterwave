#!/usr/bin/env python
"""Quick test to verify WebSocket server is working"""
import asyncio
import websockets
import json

async def test_websocket():
    try:
        uri = "ws://localhost:8000/ws/rates/"
        print(f"Connecting to {uri}...")
        async with websockets.connect(uri) as websocket:
            print("✓ Connected!")
            
            # Wait for initial all_rates message
            message = await websocket.recv()
            data = json.loads(message)
            print(f"✓ Received message type: {data.get('type')}")
            
            if data.get('type') == 'all_rates':
                rates_count = len(data.get('data', {}))
                print(f"✓ Received {rates_count} rates")
            
            print("\n✓ WebSocket is working correctly!")
    except ConnectionRefusedError:
        print("✗ Connection refused - server is not running!")
        print("  Start the server with: daphne -b 0.0.0.0 -p 8000 backend.asgi:application")
    except Exception as e:
        print(f"✗ Error: {e}")

if __name__ == "__main__":
    asyncio.run(test_websocket())

