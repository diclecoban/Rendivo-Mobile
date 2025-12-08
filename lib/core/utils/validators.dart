enum PasswordStrength { weak, medium, strong }

final _emailRegex = RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
final _upperCase = RegExp(r'[A-Z]');
final _lowerCase = RegExp(r'[a-z]');
final _digit = RegExp(r'\d');

String? validateRequired(String value, String fieldLabel, {int minLength = 1}) {
  if (value.trim().isEmpty) {
    return '$fieldLabel cannot be empty';
  }
  if (value.trim().length < minLength) {
    return '$fieldLabel must be at least $minLength characters';
  }
  return null;
}

String? validateEmail(String value) {
  if (value.trim().isEmpty) return 'Email is required';
  if (!_emailRegex.hasMatch(value.trim())) {
    return 'Enter a valid email address';
  }
  return null;
}

String? validatePassword(
  String value, {
  bool requireComplexity = true,
}) {
  if (value.isEmpty) return 'Password is required';
  if (value.length < 8) return 'Password must be at least 8 characters';

  if (!requireComplexity) return null;

  final hasUpper = _upperCase.hasMatch(value);
  final hasLower = _lowerCase.hasMatch(value);
  final hasDigit = _digit.hasMatch(value);

  if (!hasUpper || !hasLower || !hasDigit) {
    return 'Use upper, lower case letters and a digit';
  }
  return null;
}

String? validatePhone(String value) {
  if (value.trim().isEmpty) return null;
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 10) {
    return 'Phone number must include at least 10 digits';
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
