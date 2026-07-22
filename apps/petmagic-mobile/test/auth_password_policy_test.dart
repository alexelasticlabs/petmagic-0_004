import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/profile/domain/auth_password_policy.dart';

void main() {
  test('auth password policy matches backend registration requirements', () {
    expect(AuthPasswordPolicy.isValid('Password123'), isTrue);

    for (final password in const [
      'Pet1234',
      'pet12345',
      'PET12345',
      'PetMagic',
      '',
    ]) {
      expect(AuthPasswordPolicy.isValid(password), isFalse, reason: password);
    }
  });
}
