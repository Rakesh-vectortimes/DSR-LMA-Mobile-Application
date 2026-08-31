import '../../../../core/network/list_response.dart';

class Country {
  const Country({
    this.id,
    this.countryName,
    this.currencyName,
    this.currencySymbol,
    this.currency,
  });

  final String? id;
  final String? countryName;
  final String? currencyName;
  final String? currencySymbol;
  final String? currency;

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: normalizeEntityId(json['id'] ?? json['_id']),
      countryName: json['country_name'] as String?,
      currencyName: json['currency_name'] as String?,
      currencySymbol: json['currency_symbol'] as String?,
      currency: json['currency'] as String?,
    );
  }
}
