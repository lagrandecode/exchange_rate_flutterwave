class Country {
  final String name;
  final String currencyCode;
  final String countryCode; // ISO 3166-1 alpha-2 code for flag

  const Country({
    required this.name,
    required this.currencyCode,
    required this.countryCode,
  });

  String get flagUrl => 'https://flagcdn.com/w40/${countryCode.toLowerCase()}.png';
}

// Source currencies (From)
const List<Country> sourceCountries = [
  Country(name: 'United States', currencyCode: 'USD', countryCode: 'US'),
  Country(name: 'Canada', currencyCode: 'CAD', countryCode: 'CA'),
  Country(name: 'United Kingdom', currencyCode: 'GBP', countryCode: 'GB'),
  Country(name: 'Eurozone', currencyCode: 'EUR', countryCode: 'EU'),
];

// Destination countries (To) - African countries
const List<Country> destinationCountries = [
  Country(name: 'Benin', currencyCode: 'XOF', countryCode: 'BJ'),
  Country(name: 'Burkina Faso', currencyCode: 'XOF', countryCode: 'BF'),
  Country(name: 'Cameroon', currencyCode: 'XAF', countryCode: 'CM'),
  Country(name: 'Central African Republic', currencyCode: 'XAF', countryCode: 'CF'),
  Country(name: 'Chad', currencyCode: 'XAF', countryCode: 'TD'),
  Country(name: 'Egypt', currencyCode: 'EGP', countryCode: 'EG'),
  Country(name: 'Equatorial Guinea', currencyCode: 'XAF', countryCode: 'GQ'),
  Country(name: 'Ethiopia', currencyCode: 'ETB', countryCode: 'ET'),
  Country(name: 'Gabon', currencyCode: 'XAF', countryCode: 'GA'),
  Country(name: 'Ghana', currencyCode: 'GHS', countryCode: 'GH'),
  Country(name: 'Guinea Bissau', currencyCode: 'XOF', countryCode: 'GW'),
  Country(name: 'Kenya', currencyCode: 'KES', countryCode: 'KE'),
  Country(name: 'Mali', currencyCode: 'XOF', countryCode: 'ML'),
  Country(name: 'Morocco', currencyCode: 'MAD', countryCode: 'MA'),
  Country(name: 'Nigeria', currencyCode: 'NGN', countryCode: 'NG'),
  Country(name: 'Rep. Congo', currencyCode: 'XAF', countryCode: 'CG'),
  Country(name: 'Senegal', currencyCode: 'XOF', countryCode: 'SN'),
  Country(name: 'South Africa', currencyCode: 'ZAR', countryCode: 'ZA'),
  Country(name: 'Togo', currencyCode: 'XOF', countryCode: 'TG'),
  Country(name: 'Uganda', currencyCode: 'UGX', countryCode: 'UG'),
  Country(name: 'Zambia', currencyCode: 'ZMW', countryCode: 'ZM'),
];

