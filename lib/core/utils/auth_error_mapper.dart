String mapAuthErrorMessage(String code, {required bool isSignUp}) {
  switch (code) {
    case 'invalid-credential':
    case 'wrong-password':
      return 'The email or password you entered is incorrect.';
    case 'invalid-email':
      return 'That email address does not look right. Please double-check it.';
    case 'user-disabled':
      return 'This account has been disabled. Contact support if you think this is a mistake.';
    case 'user-not-found':
      return 'We could not find an account with this email.';
    case 'too-many-requests':
      return 'Too many attempts in a short time. Please wait a moment and try again.';
    case 'network-request-failed':
      return 'We could not reach the servers. Check your internet connection and try again.';
    case 'email-already-in-use':
      return isSignUp
          ? 'This email is already registered. Try logging in instead.'
          : 'This email is linked to another account.';
    case 'weak-password':
      return 'That password is easy to guess. Use at least 8 characters plus letters and numbers.';
    case 'operation-not-allowed':
      return 'Email/password sign-in is not enabled for this project.';
    default:
      return 'Something went wrong. Please try again in a moment.';
  }
}
