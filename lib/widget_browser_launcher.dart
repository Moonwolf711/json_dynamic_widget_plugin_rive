import 'package:flutter/material.dart';
import 'screens/widget_browser.dart';
import 'api/api_config.dart';

/// Utility to launch the Widget Browser from anywhere in the app
class WidgetBrowserLauncher {
  /// Open the Widget Browser as a full-screen modal
  static void open(BuildContext context, {String? apiUrl}) {
    if (apiUrl != null) {
      ApiConfig.setBaseUrl(apiUrl);
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const WidgetBrowserScreen(),
      ),
    );
  }

  /// Open the Widget Browser as a dialog
  static void openDialog(BuildContext context, {String? apiUrl}) {
    if (apiUrl != null) {
      ApiConfig.setBaseUrl(apiUrl);
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: const SizedBox(
            width: 1200,
            height: 800,
            child: WidgetBrowserScreen(),
          ),
        ),
      ),
    );
  }

  /// Create a FloatingActionButton to open the Widget Browser
  static Widget fab(BuildContext context, {String? apiUrl}) {
    return FloatingActionButton(
      onPressed: () => open(context, apiUrl: apiUrl),
      tooltip: 'Widget Browser',
      child: const Icon(Icons.widgets),
    );
  }
}
