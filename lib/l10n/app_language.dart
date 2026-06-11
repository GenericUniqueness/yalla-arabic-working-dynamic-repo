import 'package:flutter/widgets.dart';

enum AppLanguage { english, arabic }

AppLanguage appLanguageFromStorage(String? value) {
  switch (value) {
    case 'ar':
      return AppLanguage.arabic;
    case 'en':
    default:
      return AppLanguage.english;
  }
}

extension AppLanguageX on AppLanguage {
  String get storageValue => this == AppLanguage.arabic ? 'ar' : 'en';

  String get optionLabel => this == AppLanguage.arabic ? 'العربية' : 'English';

  TextDirection get textDirection =>
      this == AppLanguage.arabic ? TextDirection.rtl : TextDirection.ltr;

  bool get isArabic => this == AppLanguage.arabic;
}
