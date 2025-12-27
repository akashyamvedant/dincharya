// lib/core/security_config.dart

import 'package:flutter/foundation.dart';

class SecurityConfig {
  // File upload security
  static const int maxImageFileSize = 10 * 1024 * 1024; // 10MB
  static const int maxAudioFileSize = 50 * 1024 * 1024; // 50MB
  static const int maxDocumentFileSize = 25 * 1024 * 1024; // 25MB

  static const List<String> allowedImageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp'
  ];

  static const List<String> allowedAudioExtensions = [
    'mp3',
    'm4a',
    'wav',
    'aac',
    'ogg'
  ];

  static const List<String> allowedDocumentExtensions = [
    'pdf',
    'doc',
    'docx',
    'txt'
  ];

  // Input validation limits
  static const int maxTitleLength = 200;
  static const int maxContentLength = 5000;
  static const int maxBioLength = 500;
  static const int maxNameLength = 100;
  static const int maxPhoneLength = 20;
  static const int maxEmailLength = 254;
  static const int maxPasswordLength = 128;
  static const int minPasswordLength = 8;

  // Rate limiting
  static const int maxLoginAttempts = 5;
  static const int maxPasswordResetAttempts = 3;
  static const int maxFileUploadsPerHour = 50;
  static const int maxApiCallsPerMinute = 100;

  // Session security
  static const int sessionTimeoutMinutes = 30;
  static const int refreshTokenExpiryDays = 7;
  static const bool requireSecureConnection = true;

  // Validation patterns
  static final RegExp emailPattern =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  static final RegExp passwordPattern = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]');

  static final RegExp phonePattern = RegExp(r'^\+?[1-9]\d{1,14}$');

  static final RegExp namePattern = RegExp(r'^[a-zA-Z\s]+$');

  // Security headers
  static const Map<String, String> securityHeaders = {
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'X-XSS-Protection': '1; mode=block',
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    'Content-Security-Policy':
        "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';",
  };

  // Validation methods
  static bool isValidEmail(String email) {
    if (email.isEmpty || email.length > maxEmailLength) return false;
    return emailPattern.hasMatch(email);
  }

  static bool isValidPassword(String password) {
    if (password.length < minPasswordLength ||
        password.length > maxPasswordLength) {
      return false;
    }
    return passwordPattern.hasMatch(password);
  }

  static bool isValidPhone(String phone) {
    if (phone.isEmpty || phone.length > maxPhoneLength) return false;
    return phonePattern.hasMatch(phone);
  }

  static bool isValidName(String name) {
    if (name.isEmpty || name.length > maxNameLength) return false;
    return namePattern.hasMatch(name.trim());
  }

  static bool isValidTitle(String title) {
    return title.isEmpty ||
        (title.isNotEmpty && title.length <= maxTitleLength);
  }

  static bool isValidContent(String content) {
    return content.isEmpty ||
        (content.isNotEmpty && content.length <= maxContentLength);
  }

  static bool isValidFileSize(int fileSize, String fileType) {
    switch (fileType.toLowerCase()) {
      case 'image':
        return fileSize <= maxImageFileSize;
      case 'audio':
        return fileSize <= maxAudioFileSize;
      case 'document':
        return fileSize <= maxDocumentFileSize;
      default:
        return false;
    }
  }

  static bool isValidFileExtension(
      String fileName, List<String> allowedExtensions) {
    final extension = fileName.split('.').last.toLowerCase();
    return allowedExtensions.contains(extension);
  }

  // Sanitization methods
  static String sanitizeString(String input, {int maxLength = 1000}) {
    if (input.isEmpty) return input;

    // Remove null bytes and control characters
    String sanitized = input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

    // Trim whitespace
    sanitized = sanitized.trim();

    // Limit length
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }

    return sanitized;
  }

  static String sanitizeHtml(String input) {
    if (input.isEmpty) return input;

    // Remove HTML tags
    String sanitized = input.replaceAll(RegExp(r'<[^>]*>'), '');

    // Remove script tags and content
    sanitized = sanitized.replaceAll(
        RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '');

    // Remove event handlers
    sanitized = sanitized.replaceAll(RegExp(r'on\w+\s*='), '');

    return sanitized;
  }

  static String sanitizeFileName(String fileName) {
    if (fileName.isEmpty) return fileName;

    // Remove path traversal attempts
    String sanitized = fileName.replaceAll(RegExp(r'[./\\]'), '_');

    // Remove special characters
    sanitized = sanitized.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');

    // Limit length
    if (sanitized.length > 100) {
      sanitized = sanitized.substring(0, 100);
    }

    return sanitized;
  }

  // Security checks
  static bool isSecureConnection() {
    if (kIsWeb) {
      // Web security checks
      return true; // Assume HTTPS in production
    }
    return true; // Mobile apps are generally secure
  }

  static bool shouldRequireReauthentication() {
    // Implement logic to determine if re-authentication is needed
    // Based on session age, user actions, etc.
    return false;
  }

  // Logging and monitoring
  static void logSecurityEvent(String event,
      {String? userId, String? details}) {
    if (kDebugMode) {
      print('SECURITY EVENT: $event - User: $userId - Details: $details');
    }
    // In production, send to security monitoring service
  }

  static void logValidationFailure(String field, String value, String reason) {
    logSecurityEvent('VALIDATION_FAILURE',
        details: 'Field: $field, Value: $value, Reason: $reason');
  }

  static void logSecurityViolation(String violation,
      {String? userId, String? details}) {
    logSecurityEvent('SECURITY_VIOLATION',
        userId: userId, details: '$violation - $details');
  }
}


