import logging
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.conf import settings
from django.utils import timezone
from datetime import timedelta
from .cache import get_rate, set_rate
from .services import fetch_flutterwave_rate, to_backend_shape, save_rate_to_db
from .models import ExchangeRate

logger = logging.getLogger(__name__)


class RatesView(APIView):
    """
    GET /api/rates/?source_currency=NGN&destination_currency=CAD&amount=1
    Returns the same JSON shape as Flutterwave.
    """

    def get(self, request):
        source_currency = request.query_params.get('source_currency')
        destination_currency = request.query_params.get('destination_currency')
        if not source_currency or not destination_currency:
            return Response(
                {"status": "error", "message": "source_currency and destination_currency are required", "data": None},
                status=status.HTTP_400_BAD_REQUEST,
            )

        source_currency = source_currency.upper()
        destination_currency = destination_currency.upper()

        # First check Redis cache
        cached = get_rate(source_currency, destination_currency)
        if cached:
            return Response(cached, status=status.HTTP_200_OK)

        # Then check database (rates are pre-fetched and stored)
        try:
            db_rate = ExchangeRate.objects.get(
                source_currency=source_currency,
                destination_currency=destination_currency
            )
            # Ensure data is fresh; if stale, fetch a new quote from Flutterwave
            is_stale = timezone.now() - db_rate.last_updated > timedelta(minutes=10)
            if is_stale:
                try:
                    fw_resp = fetch_flutterwave_rate(source_currency, destination_currency)
                    if fw_resp.get('status') == 'success':
                        save_rate_to_db(source_currency, destination_currency, fw_resp)
                        shaped = to_backend_shape(fw_resp)
                        set_rate(source_currency, destination_currency, shaped)
                        return Response(shaped, status=status.HTTP_200_OK)
                except Exception as e:
                    logger.warning(
                        "Failed to refresh stale rate %s->%s: %s. Falling back to cached DB value.",
                        source_currency,
                        destination_currency,
                        e,
                    )
            # Convert DB model to Flutterwave response shape
            shaped = {
                "status": "success",
                "message": "Transfer amount fetched",
                "data": {
                    "rate": float(db_rate.rate),
                    "source": {
                        "currency": db_rate.source_currency,
                        "amount": float(db_rate.source_amount)
                    },
                    "destination": {
                        "currency": db_rate.destination_currency,
                        "amount": float(db_rate.destination_amount)
                    }
                }
            }
            # Cache in Redis for faster access
            set_rate(source_currency, destination_currency, shaped)
            return Response(shaped, status=status.HTTP_200_OK)
        except ExchangeRate.DoesNotExist:
            # If not in DB, fetch from Flutterwave as fallback
            try:
                fw_resp = fetch_flutterwave_rate(source_currency, destination_currency)
                if fw_resp.get('status') == 'success':
                    # Save to database for future use
                    save_rate_to_db(source_currency, destination_currency, fw_resp)
                    shaped = to_backend_shape(fw_resp)
                    set_rate(source_currency, destination_currency, shaped)
                    return Response(shaped, status=status.HTTP_200_OK)
            except Exception as e:
                logger.exception(f"Failed to fetch Flutterwave rate: {e}")
                return Response(
                    {"status": "error", "message": f"Failed to fetch rates: {str(e)}", "data": None},
                    status=status.HTTP_502_BAD_GATEWAY,
                )

        return Response(
            {"status": "error", "message": "Rate not found", "data": None},
            status=status.HTTP_404_NOT_FOUND,
        )


class AllRatesView(APIView):
    """
    GET /api/rates/all/?base_currency=NGN
    Returns all popular currency pairs for a base currency.
    Fetches from cache first, then Flutterwave for missing pairs.
    """

    # Destination currencies (African countries)
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

    # Source currencies
    SOURCE_CURRENCIES = ['USD', 'CAD', 'GBP', 'EUR']

    def get(self, request):
        base_currency = request.query_params.get('base_currency', 'USD').upper()
        
        results = {}

        # Fetch all rates from database (pre-fetched and stored)
        for dest_currency in self.DESTINATION_CURRENCIES:
            if dest_currency == base_currency:
                continue
            
            # Check Redis cache first
            cached = get_rate(base_currency, dest_currency)
            if cached:
                results[f"{base_currency}_{dest_currency}"] = cached
                continue

            # Then check database
            try:
                db_rate = ExchangeRate.objects.get(
                    source_currency=base_currency,
                    destination_currency=dest_currency
                )
                # Convert to Flutterwave response shape
                shaped = {
                    "status": "success",
                    "message": "Transfer amount fetched",
                    "data": {
                        "rate": float(db_rate.rate),
                        "source": {
                            "currency": db_rate.source_currency,
                            "amount": float(db_rate.source_amount)
                        },
                        "destination": {
                            "currency": db_rate.destination_currency,
                            "amount": float(db_rate.destination_amount)
                        }
                    }
                }
                results[f"{base_currency}_{dest_currency}"] = shaped
                # Cache in Redis
                set_rate(base_currency, dest_currency, shaped)
            except ExchangeRate.DoesNotExist:
                # If not in DB, skip (will be fetched by background job)
                logger.warning(f"Rate not found in DB: {base_currency}->{dest_currency}")

        return Response({
            "status": "success",
            "message": "Rates fetched",
            "data": results
        }, status=status.HTTP_200_OK)


class RateChangeCheckView(APIView):
    """
    GET /api/rates/check-changes/
    Checks if exchange rates have been updated in the last 5 days.
    Returns information about which rates have changed and when.
    """

    def get(self, request):
        # Calculate the date 5 days ago
        five_days_ago = timezone.now() - timedelta(days=5)
        
        # Find all rates that have been updated in the last 5 days
        updated_rates = ExchangeRate.objects.filter(
            last_updated__gte=five_days_ago
        ).order_by('-last_updated')
        
        # Count total rates and updated rates
        total_rates = ExchangeRate.objects.count()
        updated_count = updated_rates.count()
        
        # Prepare response data
        changed_rates = []
        for rate in updated_rates:
            changed_rates.append({
                "source_currency": rate.source_currency,
                "destination_currency": rate.destination_currency,
                "rate": float(rate.rate),
                "last_updated": rate.last_updated.isoformat(),
                "days_since_update": (timezone.now() - rate.last_updated).days,
                "hours_since_update": round((timezone.now() - rate.last_updated).total_seconds() / 3600, 2)
            })
        
        # Check if any rates have changed
        has_changes = updated_count > 0
        
        return Response({
            "status": "success",
            "message": "Rate change check completed",
            "data": {
                "has_changes": has_changes,
                "total_rates": total_rates,
                "updated_in_last_5_days": updated_count,
                "check_period_days": 5,
                "check_date": five_days_ago.isoformat(),
                "changed_rates": changed_rates
            }
        }, status=status.HTTP_200_OK)


