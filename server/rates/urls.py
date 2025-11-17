from django.urls import path
from .views import RatesView, AllRatesView

urlpatterns = [
    path('rates/', RatesView.as_view(), name='rates'),
    path('rates/all/', AllRatesView.as_view(), name='all-rates'),
]


