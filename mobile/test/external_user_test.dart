import 'package:flutter_test/flutter_test.dart';
import 'package:assignment_app/features/users/data/external_user.dart';

void main() {
  const json = {
    'id': 1,
    'name': 'Leanne Graham',
    'username': 'Bret',
    'email': 'Sincere@april.biz',
    'address': {
      'street': 'Kulas Light',
      'suite': 'Apt. 556',
      'city': 'Gwenborough',
      'zipcode': '92998-3874',
      'geo': {'lat': '-37.3159', 'lng': '81.1496'},
    },
    'phone': '1-770-736-8031 x56442',
    'website': 'hildegard.org',
    'company': {
      'name': 'Romaguera-Crona',
      'catchPhrase': 'Multi-layered client-server',
      'bs': 'harness real-time e-markets',
    },
  };

  test('parses the full external user object', () {
    final u = ExternalUser.fromJson(json);
    expect(u.id, 1);
    expect(u.name, 'Leanne Graham');
    expect(u.email, 'Sincere@april.biz');
    expect(u.address.city, 'Gwenborough');
    expect(u.address.geo.lat, '-37.3159');
    expect(u.company.name, 'Romaguera-Crona');
    expect(u.company.catchPhrase, 'Multi-layered client-server');
  });

  test('tolerates missing/null fields', () {
    final u = ExternalUser.fromJson({'id': 2});
    expect(u.name, '');
    expect(u.address.city, '');
    expect(u.company.name, '');
    expect(u.phone, '');
  });

  test('initials from first + last word', () {
    expect(ExternalUser.fromJson(json).initials, 'LG');
    expect(ExternalUser.fromJson({...json, 'name': 'Cher'}).initials, 'C');
    expect(ExternalUser.fromJson({...json, 'name': ''}).initials, '?');
  });
}
