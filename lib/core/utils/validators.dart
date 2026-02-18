class Validators {
  static bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  static bool isValidPassword(String password) {
    return password.length >= 8 &&
        RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]')
            .hasMatch(password);
  }

  static bool isValidUserId(String userId) {
    return userId.isNotEmpty && userId.length <= 100;
  }

  static bool isValidString(String? str, {int maxLength = 1000}) {
    return str != null && str.isNotEmpty && str.length <= maxLength;
  }

  static bool isValidPhone(String phone) {
    // Allow empty phone (Google Play handles user identity)
    if (phone.isEmpty) return true;
    // Accept Indian phone: 10 digits, optionally with +91 prefix
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return RegExp(r'^(\+91)?[6-9]\d{9}$').hasMatch(cleaned);
  }

  static bool isValidName(String name) {
    // Allow empty name (Google Play handles user identity)
    if (name.isEmpty) return true;
    return name.length <= 100;
  }

  static bool isValidAmount(double amount) {
    return amount > 0 && amount <= 100000; // Max 1 lakh INR
  }
}
