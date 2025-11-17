import 'package:flutter/material.dart';

import '../models/country.dart';

class CountryDropdown extends StatelessWidget {
  const CountryDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.countries,
    required this.onChanged,
  });

  final String label;
  final Country value;
  final List<Country> countries;
  final ValueChanged<Country?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Country>(
      // ignore: deprecated_member_use
      value: value,
      items: countries
          .map(
            (country) => DropdownMenuItem<Country>(
              value: country,
              child: SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    Image.network(
                      country.flagUrl,
                      width: 24,
                      height: 18,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(
                        width: 24,
                        height: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        country.name,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        country.currencyCode,
                        style: TextStyle(
                          fontSize: 12,
                          // ignore: deprecated_member_use
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      selectedItemBuilder: (context) {
        return countries.map((country) {
          return Text(
            '${country.name} (${country.currencyCode})',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          );
        }).toList();
      },
    );
  }
}

