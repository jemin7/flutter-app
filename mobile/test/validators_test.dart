import 'package:flutter_test/flutter_test.dart';
import 'package:assignment_app/core/validators.dart';

void main() {
  group('Validators.email', () {
    test('accepts valid emails', () {
      expect(Validators.email('user@example.com'), isNull);
      expect(Validators.email(' first.last@sub.domain.org '), isNull);
    });

    test('rejects invalid emails', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('nope'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
      expect(Validators.email(null), isNotNull);
    });
  });

  group('Validators.username', () {
    test('3-20 alphanumeric/underscore only', () {
      expect(Validators.username('abc'), isNull);
      expect(Validators.username('user_01'), isNull);
      expect(Validators.username('ab'), isNotNull); // too short
      expect(Validators.username('a' * 21), isNotNull); // too long
      expect(Validators.username('bad name'), isNotNull); // space
      expect(Validators.username('bad-name!'), isNotNull);
      expect(Validators.username(''), isNotNull);
    });
  });

  group('Validators.password', () {
    test('enforces all four character classes and length', () {
      expect(Validators.password('Passw0rd!'), isNull);
      expect(Validators.password(null), isNotNull);
      expect(Validators.password('Short1!'), isNotNull); // < 8 chars
      expect(Validators.password('alllower1!'), isNotNull); // no upper
      expect(Validators.password('ALLUPPER1!'), isNotNull); // no lower
      expect(Validators.password('NoDigits!!'), isNotNull); // no digit
      expect(Validators.password('NoSpecial11'), isNotNull); // no special
    });
  });

  group('Validators.confirmPassword', () {
    test('must match the other field', () {
      final validate = Validators.confirmPassword(() => 'Passw0rd!');
      expect(validate('Passw0rd!'), isNull);
      expect(validate('Different1!'), isNotNull);
      expect(validate(''), isNotNull);
    });
  });

  group('Validators.identifier', () {
    test('accepts any non-empty username or email', () {
      expect(Validators.identifier('hemant'), isNull);
      expect(Validators.identifier('hemant@test.com'), isNull);
      expect(Validators.identifier('   '), isNotNull);
      expect(Validators.identifier(null), isNotNull);
    });
  });

  group('Validators.fullName', () {
    test('requires non-empty trimmed value', () {
      expect(Validators.fullName('Hemant Kumar'), isNull);
      expect(Validators.fullName('   '), isNotNull);
      expect(Validators.fullName(''), isNotNull);
    });
  });
}
