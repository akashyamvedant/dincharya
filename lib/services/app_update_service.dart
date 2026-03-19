// lib/services/app_update_service.dart
// Google Play In-App Updates — Flexible + Immediate flows

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

class AppUpdateService {
  AppUpdateInfo? _updateInfo;

  /// Check if an update is available on the Play Store.
  /// Returns the [AppUpdateInfo] if available, null otherwise.
  /// Silently fails on non-Play-Store installs (debug builds, sideload).
  Future<AppUpdateInfo?> checkForUpdate() async {
    // In-App Updates only work on Android
    if (!Platform.isAndroid) return null;

    try {
      final info = await InAppUpdate.checkForUpdate();
      _updateInfo = info;
      debugPrint('🔄 Update info — available: ${info.updateAvailability}, '
          'immediateAllowed: ${info.immediateUpdateAllowed}, '
          'flexibleAllowed: ${info.flexibleUpdateAllowed}, '
          'staleness: ${info.clientVersionStalenessDays}');
      return info;
    } catch (e) {
      // Expected in debug builds / non-Play-Store installs
      debugPrint('⚠️ In-app update check failed (expected in debug): $e');
      return null;
    }
  }

  /// Whether an update is actually available
  bool get isUpdateAvailable =>
      _updateInfo?.updateAvailability == UpdateAvailability.updateAvailable;

  /// Whether this is a critical update (stale > 3 days)
  bool get isCriticalUpdate =>
      (_updateInfo?.clientVersionStalenessDays ?? 0) >= 3;

  /// Whether immediate update is allowed by Play Store
  bool get canDoImmediateUpdate =>
      _updateInfo?.immediateUpdateAllowed ?? false;

  /// Whether flexible update is allowed by Play Store
  bool get canDoFlexibleUpdate =>
      _updateInfo?.flexibleUpdateAllowed ?? false;

  /// Start a FLEXIBLE update (background download, non-blocking).
  /// Returns true if started successfully.
  Future<bool> startFlexibleUpdate() async {
    try {
      await InAppUpdate.startFlexibleUpdate();
      return true;
    } catch (e) {
      debugPrint('⚠️ Flexible update failed: $e');
      return false;
    }
  }

  /// Complete a previously downloaded flexible update (triggers install).
  Future<void> completeFlexibleUpdate() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      debugPrint('⚠️ Complete flexible update failed: $e');
    }
  }

  /// Start an IMMEDIATE update (full-screen, mandatory).
  /// User cannot continue until the update is installed.
  Future<void> startImmediateUpdate() async {
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      debugPrint('⚠️ Immediate update failed: $e');
    }
  }
}
