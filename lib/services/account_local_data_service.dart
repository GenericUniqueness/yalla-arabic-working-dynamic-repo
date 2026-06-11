import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

class AccountLocalDataService {
  const AccountLocalDataService._();

  static Future<void> clearAll() async {
    try {
      await NotificationService.cancelReminder();
    } catch (_) {
      // Preference cleanup must still run if the platform notification call
      // is unavailable while the account is being deleted.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
