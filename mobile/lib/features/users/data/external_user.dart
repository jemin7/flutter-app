/// The full JSONPlaceholder user object as proxied by OUR backend.
class ExternalUser {
  const ExternalUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.address,
    required this.phone,
    required this.website,
    required this.company,
  });

  final int id;
  final String name;
  final String username;
  final String email;
  final Address address;
  final String phone;
  final String website;
  final Company company;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'))..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory ExternalUser.fromJson(Map<String, dynamic> json) => ExternalUser(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
        address: Address.fromJson(json['address'] as Map<String, dynamic>? ?? {}),
        phone: json['phone'] as String? ?? '',
        website: json['website'] as String? ?? '',
        company: Company.fromJson(json['company'] as Map<String, dynamic>? ?? {}),
      );
}

class Address {
  const Address({required this.street, required this.suite, required this.city, required this.zipcode, required this.geo});

  final String street;
  final String suite;
  final String city;
  final String zipcode;
  final Geo geo;

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        street: json['street'] as String? ?? '',
        suite: json['suite'] as String? ?? '',
        city: json['city'] as String? ?? '',
        zipcode: json['zipcode'] as String? ?? '',
        geo: Geo.fromJson(json['geo'] as Map<String, dynamic>? ?? {}),
      );
}

class Geo {
  const Geo({required this.lat, required this.lng});

  final String lat;
  final String lng;

  factory Geo.fromJson(Map<String, dynamic> json) => Geo(
        lat: json['lat']?.toString() ?? '',
        lng: json['lng']?.toString() ?? '',
      );
}

class Company {
  const Company({required this.name, required this.catchPhrase, required this.bs});

  final String name;
  final String catchPhrase;
  final String bs;

  factory Company.fromJson(Map<String, dynamic> json) => Company(
        name: json['name'] as String? ?? '',
        catchPhrase: json['catchPhrase'] as String? ?? '',
        bs: json['bs'] as String? ?? '',
      );
}
