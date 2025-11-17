from django.db import models
from django.utils import timezone


class ExchangeRate(models.Model):
    """Store exchange rates fetched from Flutterwave."""
    source_currency = models.CharField(max_length=3, db_index=True)
    destination_currency = models.CharField(max_length=3, db_index=True)
    rate = models.DecimalField(max_digits=20, decimal_places=8)
    source_amount = models.DecimalField(max_digits=20, decimal_places=2)
    destination_amount = models.DecimalField(max_digits=20, decimal_places=2)
    last_updated = models.DateTimeField(auto_now=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'exchange_rates'
        unique_together = [['source_currency', 'destination_currency']]
        indexes = [
            models.Index(fields=['source_currency', 'destination_currency']),
            models.Index(fields=['last_updated']),
        ]

    def __str__(self):
        return f"{self.source_currency} -> {self.destination_currency}: {self.rate}"

