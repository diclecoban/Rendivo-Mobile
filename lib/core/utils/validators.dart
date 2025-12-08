enum PasswordStrength { weak, medium, strong }

final _emailRegex = RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
final _upperCase = RegExp(r'[A-Z]');
final _lowerCase = RegExp(r'[a-z]');
final _digit = RegExp(r'\d');

String? validateRequired(String value, String fieldLabel, {int minLength = 1}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'Please enter your $fieldLabel.';
  }
  if (trimmed.length < minLength) {
    return '$fieldLabel should be at least $minLength characters.';
  }
  return null;
}

String? validateEmail(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'Please enter your email address.';
  if (!_emailRegex.hasMatch(trimmed)) {
    return 'That email does not look right. Please check it again.';
  }
  return null;
}

String? validatePassword(
  String value, {
  bool requireComplexity = true,
}) {
  if (value.isEmpty) return 'Please create a password.';
  if (value.length < 8) return 'Use at least 8 characters.';

  if (!requireComplexity) return null;

  final hasUpper = _upperCase.hasMatch(value);
  final hasLower = _lowerCase.hasMatch(value);
  final hasDigit = _digit.hasMatch(value);

  if (!hasUpper || !hasLower || !hasDigit) {
    return 'Add at least one upper-case letter, one lower-case letter, and a number.';
  }
  return null;
}

String? validatePhone(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 10) {
    return 'Phone numbers need at least 10 digits.';
  }
  return null;
}

PasswordStrength evaluatePasswordStrength(String password) {
  if (password.length >= 12 &&
      _upperCase.hasMatch(password) &&
      _lowerCase.hasMatch(password) &&
      _digit.hasMatch(password)) {
    return PasswordStrength.strong;
  }

  if (password.length >= 10 &&
      ((_upperCase.hasMatch(password) && _lowerCase.hasMatch(password)) ||
          (_upperCase.hasMatch(password) && _digit.hasMatch(password)) ||
          (_lowerCase.hasMatch(password) && _digit.hasMatch(password)))) {
    return PasswordStrength.medium;
  }

  return PasswordStrength.weak;
}
