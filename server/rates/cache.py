from django.core.cache import cache
from typing import Optional, Dict, Any


def _key(source_currency: str, destination_currency: str) -> str:
    return f"fxrate:{source_currency.upper()}:{destination_currency.upper()}"


def get_rate(source_currency: str, destination_currency: str) -> Optional[Dict[str, Any]]:
    return cache.get(_key(source_currency, destination_currency))


def set_rate(source_currency: str, destination_currency: str, payload: Dict[str, Any], ttl_seconds: int = 120) -> None:
    cache.set(_key(source_currency, destination_currency), payload, ttl_seconds)


