import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from .models import ExchangeRate


class RatesConsumer(AsyncWebsocketConsumer):
    """WebSocket consumer for real-time exchange rate updates."""

    async def connect(self):
        """Handle WebSocket connection."""
        await self.accept()
        # Join rates update group
        await self.channel_layer.group_add('rates_updates', self.channel_name)
        # Send all current rates on connection
        await self.send_all_rates()

    async def disconnect(self, close_code):
        """Handle WebSocket disconnection."""
        # Leave rates update group
        await self.channel_layer.group_discard('rates_updates', self.channel_name)

    async def receive(self, text_data):
        """Handle messages from client."""
        try:
            data = json.loads(text_data)
            message_type = data.get('type')

            if message_type == 'get_all_rates':
                await self.send_all_rates()
            elif message_type == 'get_rate':
                source_currency = data.get('source_currency')
                destination_currency = data.get('destination_currency')
                if source_currency and destination_currency:
                    await self.send_rate(source_currency, destination_currency)
        except json.JSONDecodeError:
            pass

    async def rate_update(self, event):
        """Send rate update to WebSocket."""
        await self.send(text_data=json.dumps({
            'type': 'rate_update',
            'data': event['data']
        }))

    async def all_rates_update(self, event):
        """Send all rates update to WebSocket."""
        await self.send(text_data=json.dumps({
            'type': 'all_rates_update',
            'data': event['data']
        }))

    async def send_all_rates(self):
        """Send all rates for all source currencies."""
        all_rates = await self.get_all_rates_from_db()
        await self.send(text_data=json.dumps({
            'type': 'all_rates',
            'data': all_rates
        }))

    async def send_rate(self, source_currency: str, destination_currency: str):
        """Send a specific rate."""
        rate = await self.get_rate_from_db(source_currency, destination_currency)
        if rate:
            await self.send(text_data=json.dumps({
                'type': 'rate',
                'data': rate
            }))

    @database_sync_to_async
    def get_all_rates_from_db(self):
        """Get all rates from database."""
        try:
            source_currencies = ['USD', 'CAD', 'GBP', 'EUR']
            destination_currencies = [
                'XOF', 'XAF', 'EGP', 'ETB', 'GHS', 'KES',
                'MAD', 'NGN', 'ZAR', 'UGX', 'ZMW'
            ]

            results = {}
            for source in source_currencies:
                for dest in destination_currencies:
                    if source == dest:
                        continue
                    try:
                        rate_obj = ExchangeRate.objects.get(
                            source_currency=source,
                            destination_currency=dest
                        )
                        results[f"{source}_{dest}"] = {
                            "status": "success",
                            "message": "Transfer amount fetched",
                            "data": {
                                "rate": float(rate_obj.rate),
                                "source": {
                                    "currency": rate_obj.source_currency,
                                    "amount": float(rate_obj.source_amount)
                                },
                                "destination": {
                                    "currency": rate_obj.destination_currency,
                                    "amount": float(rate_obj.destination_amount)
                                }
                            }
                        }
                    except ExchangeRate.DoesNotExist:
                        pass
            return results
        except Exception:
            # Database table might not exist yet, return empty dict
            return {}

    @database_sync_to_async
    def get_rate_from_db(self, source_currency: str, destination_currency: str):
        """Get a specific rate from database."""
        try:
            rate_obj = ExchangeRate.objects.get(
                source_currency=source_currency.upper(),
                destination_currency=destination_currency.upper()
            )
            return {
                "status": "success",
                "message": "Transfer amount fetched",
                "data": {
                    "rate": float(rate_obj.rate),
                    "source": {
                        "currency": rate_obj.source_currency,
                        "amount": float(rate_obj.source_amount)
                    },
                    "destination": {
                        "currency": rate_obj.destination_currency,
                        "amount": float(rate_obj.destination_amount)
                    }
                }
            }
        except ExchangeRate.DoesNotExist:
            return None

