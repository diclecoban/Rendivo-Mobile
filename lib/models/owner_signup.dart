class OwnerSignupModel {
  OwnerSignupModel._();
  static final instance = OwnerSignupModel._();

  String firstName = '';
  String lastName = '';
  String email = '';
  String password = '';

  String businessName = '';
  String businessType = '';
  String street = '';
  String city = '';
  String state = '';
  String postalCode = '';
  String phone = '';
  String publicEmail = '';

  String get fullName {
    final parts = <String>[];
    if (firstName.trim().isNotEmpty) {
      parts.add(firstName.trim());
    }
    if (lastName.trim().isNotEmpty) {
      parts.add(lastName.trim());
    }
    return parts.join(' ').trim();
  }

  set fullName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      firstName = '';
      lastName = '';
      return;
    }

    final segments = trimmed.split(RegExp(r'\s+'));
    firstName = segments.first;
    lastName = segments.length > 1
        ? segments.sublist(1).join(' ')
        : '';
  }
}
