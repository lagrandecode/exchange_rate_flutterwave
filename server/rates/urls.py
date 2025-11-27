from django.urls import path
from .views import RatesView, AllRatesView, RateChangeCheckView

urlpatterns = [
    path('rates/', RatesView.as_view(), name='rates'),
    path('rates/all/', AllRatesView.as_view(), name='all-rates'),
    path('rates/check-changes/', RateChangeCheckView.as_view(), name='rate-change-check'),
]


