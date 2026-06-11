import 'package:flutter/foundation.dart';

class QaBuildConfig {
  static const _wordPanelQa = bool.fromEnvironment('QA_WORD_PANEL');

  static bool get bypassAuth => true;
  static bool get wordPanelQa => kDebugMode && _wordPanelQa;

  static const guestUid = 'yalla_arabic_local_guest';
  static const guestEmail = 'local-dev@yallaarabic.test';
  static const bannerTitle = 'YALLA ARABIC DEV BUILD';
}
