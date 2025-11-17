import os
import time
import requests
from typing import Dict, Any
from django.conf import settings
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


def _create_session_with_retries() -> requests.Session:
    """Create a requests session with retry logic."""
    session = requests.Session()
    retry_strategy = Retry(
        total=3,
        backoff_factor=1,
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=["GET"]
    )
    adapter = HTTPAdapter(max_retries=retry_strategy)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    return session


def fetch_flutterwave_rate(source_currency: str, destination_currency: str) -> Dict[str, Any]:
    """
    Call Flutterwave transfers/rates with amount=1 to get a per-unit quote.
    Returns the response body (dict). Raises on non-2xx.
    """
    base_url = "https://api.flutterwave.com/v3/transfers/rates"
    params = {
        "amount": "1",
        "source_currency": source_currency.upper(),
        "destination_currency": destination_currency.upper(),
    }
    headers = {
        "Authorization": f"Bearer {settings.FLUTTERWAVE_SECRET_KEY}",
        "Content-Type": "application/json",
    }
    
    # Use session with retries and longer timeout
    session = _create_session_with_retries()
    try:
        resp = session.get(base_url, params=params, headers=headers, timeout=30)
        resp.raise_for_status()
        return resp.json()
    finally:
        session.close()


def to_backend_shape(resp: Dict[str, Any]) -> Dict[str, Any]:
    """
    Ensure we return exactly Flutterwave's successful JSON shape.
    """
    # If Flutterwave already returns the shape, pass-through.
    return resp


def save_rate_to_db(source_currency: str, destination_currency: str, fw_response: Dict[str, Any]) -> None:
    """
    Save exchange rate to database from Flutterwave response.
    """
    from .models import ExchangeRate
    
    if fw_response.get('status') != 'success':
        return
    
    data = fw_response.get('data', {})
    rate_value = data.get('rate')
    source_data = data.get('source', {})
    dest_data = data.get('destination', {})
    
    if not rate_value:
        return
    
    ExchangeRate.objects.update_or_create(
        source_currency=source_currency.upper(),
        destination_currency=destination_currency.upper(),
        defaults={
            'rate': rate_value,
            'source_amount': source_data.get('amount', 0),
            'destination_amount': dest_data.get('amount', 0),
        }
    )


