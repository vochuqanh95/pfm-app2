// Password validation utility for enforcing password policy across the app.
//
// Password policy requirements:
// - Minimum length: 8 characters
// - At least 1 uppercase letter (A-Z)
// - At least 1 lowercase letter (a-z)
// - At least 1 digit (0-9)
// - At least 1 special character
// - No spaces allowed

/// Password hint to display to users
const String kPasswordHint =
    "At least 8 characters, including uppercase, lowercase, digit, and special character. No spaces.";

/// Validates a password against the app's password policy.
///
/// Returns `null` if the password meets all requirements.
/// Returns a user-friendly error message if validation fails.
///
/// Example:
/// ```dart
/// final error = validatePassword("weak");
/// if (error != null) {
///   // Show error to user
/// }
/// ```
String? validatePassword(String password) {
  // Check for empty password
  if (password.isEmpty) {
    return 'Please enter a password';
  }

  // Check minimum length
  if (password.length < 8) {
    return 'Password must be at least 8 characters long';
  }

  // Check for spaces
  if (password.contains(' ')) {
    return 'Password must not contain spaces';
  }

  // Check for at least one uppercase letter
  if (!RegExp(r'[A-Z]').hasMatch(password)) {
    return 'Password must include at least one uppercase letter';
  }

  // Check for at least one lowercase letter
  if (!RegExp(r'[a-z]').hasMatch(password)) {
    return 'Password must include at least one lowercase letter';
  }

  // Check for at least one digit
  if (!RegExp(r'[0-9]').hasMatch(password)) {
    return 'Password must include at least one digit';
  }

  // Check for at least one special character
  // Common special characters: !@#$%^&*()-_+=[]{}|;:'",.<>?/\
  if (!RegExp(r'''[!@#$%^&*()\-_+=\[\]{}|;:'",.<>?/\\]''').hasMatch(password)) {
    return 'Password must include at least one special character';
  }

  // All checks passed
  return null;
}
