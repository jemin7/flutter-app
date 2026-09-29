/// Mirrors backend/src/middleware/validators.js — identical messages.
class Validators {
  Validators._();

  static String? fullName(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Full name is required';
    return null;
  }

  static String? username(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Username is required';
    if (value.length < 3 || value.length > 20) return 'Username must be 3-20 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) return 'Only letters, numbers and underscore';
    return null;
  }

  static String? email(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(value)) return 'Invalid email address';
    return null;
  }

  static String? password(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Add an uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Add a lowercase letter';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Add a digit';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) return 'Add a special character';
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() other) {
    return (v) {
      final value = v ?? '';
      if (value.isEmpty) return 'Confirm password is required';
      if (value != other()) return 'Passwords do not match';
      return null;
    };
  }

  /// Login accepts username OR email: anything non-empty.
  static String? identifier(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Username or email is required';
    return null;
  }
}
