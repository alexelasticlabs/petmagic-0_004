/// Domain password policy shared by profile application flows.
class AuthPasswordPolicy {
  const AuthPasswordPolicy._();

  static const minLength = 8;
  static const errorMessage = 'auth.password_policy_invalid';

  static final RegExp _uppercase = RegExp(r'[A-Z]');
  static final RegExp _lowercase = RegExp(r'[a-z]');
  static final RegExp _digit = RegExp(r'[0-9]');

  static bool isValid(String password) {
    return password.length >= minLength &&
        _uppercase.hasMatch(password) &&
        _lowercase.hasMatch(password) &&
        _digit.hasMatch(password);
  }
}
