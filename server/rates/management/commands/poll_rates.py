import time
from django.core.management.base import BaseCommand
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from rates.cache import set_rate
from rates.services import fetch_flutterwave_rate, save_rate_to_db, to_backend_shape


class Command(BaseCommand):
    help = "Fetches all exchange rates from Flutterwave and stores them in the database. Runs every 10 minutes."

    # Source currencies (From)
    SOURCE_CURRENCIES = ['USD', 'CAD', 'GBP', 'EUR']
    
    # Destination currencies (To) - African countries
    DESTINATION_CURRENCIES = [
        'XOF',  # Benin, Burkina Faso, Guinea Bissau, Mali, Senegal, Togo
        'XAF',  # Cameroon, CAR, Chad, Equatorial Guinea, Gabon, Rep. Congo
        'EGP',  # Egypt
        'ETB',  # Ethiopia
        'GHS',  # Ghana
        'KES',  # Kenya
        'MAD',  # Morocco
        'NGN',  # Nigeria
        'ZAR',  # South Africa
        'UGX',  # Uganda
        'ZMW',  # Zambia
    ]

    def add_arguments(self, parser):
        parser.add_argument(
            '--interval',
            type=int,
            default=600,  # 10 minutes in seconds
            help='Polling interval in seconds (default: 600 = 10 minutes)'
        )
        parser.add_argument(
            '--once',
            action='store_true',
            help='Run once and exit (for cron jobs)'
        )

    def handle(self, *args, **options):
        interval = options['interval']
        run_once = options['once']
        
        total_pairs = len(self.SOURCE_CURRENCIES) * len(self.DESTINATION_CURRENCIES)
        self.stdout.write(
            self.style.SUCCESS(
                f"Starting rate fetcher. Will fetch {total_pairs} currency pairs every {interval}s"
            )
        )

        while True:
            success_count = 0
            error_count = 0
            
            for source_currency in self.SOURCE_CURRENCIES:
                for dest_currency in self.DESTINATION_CURRENCIES:
                    # Skip same currency
                    if source_currency == dest_currency:
                        continue
                    
                    try:
                        fw_resp = fetch_flutterwave_rate(source_currency, dest_currency)
                        if fw_resp.get('status') == 'success':
                            # Save to database
                            save_rate_to_db(source_currency, dest_currency, fw_resp)
                            
                            # Also cache in Redis for faster access
                            shaped = to_backend_shape(fw_resp)
                            set_rate(source_currency, dest_currency, shaped, ttl_seconds=interval * 2)
                            
                            # Broadcast update via WebSocket
                            self.broadcast_rate_update(source_currency, dest_currency, shaped)
                            
                            success_count += 1
                            self.stdout.write(
                                self.style.SUCCESS(f"✓ {source_currency}->{dest_currency}")
                            )
                        else:
                            error_count += 1
                            self.stdout.write(
                                self.style.WARNING(
                                    f"✗ {source_currency}->{dest_currency}: {fw_resp.get('message', 'Unknown error')}"
                                )
                            )
                    except Exception as e:
                        error_count += 1
                        self.stdout.write(
                            self.style.ERROR(f"✗ {source_currency}->{dest_currency}: {str(e)}")
                        )
                    
                    # Small delay to avoid rate limiting
                    time.sleep(0.5)
            
            self.stdout.write(
                self.style.SUCCESS(
                    f"\nCompleted: {success_count} successful, {error_count} errors\n"
                )
            )
            
            # Broadcast all rates update after completing all pairs
            if success_count > 0:
                self.broadcast_all_rates_update()
            
            if run_once:
                break
            
            self.stdout.write(f"Waiting {interval}s until next fetch...\n")
            time.sleep(interval)

    def broadcast_rate_update(self, source_currency: str, destination_currency: str, rate_data: dict):
        """Broadcast rate update to all connected WebSocket clients."""
        try:
            channel_layer = get_channel_layer()
            async_to_sync(channel_layer.group_send)(
                'rates_updates',
                {
                    'type': 'rate_update',
                    'data': {
                        'key': f"{source_currency}_{destination_currency}",
                        'rate': rate_data
                    }
                }
            )
        except Exception as e:
            # Silently fail if WebSocket broadcasting fails
            pass

    def broadcast_all_rates_update(self):
        """Broadcast that all rates have been updated."""
        try:
            channel_layer = get_channel_layer()
            async_to_sync(channel_layer.group_send)(
                'rates_updates',
                {
                    'type': 'all_rates_update',
                    'data': {}
                }
            )
        except Exception as e:
            # Silently fail if WebSocket broadcasting fails
            pass


