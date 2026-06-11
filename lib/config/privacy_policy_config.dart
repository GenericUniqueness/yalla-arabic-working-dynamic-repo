class PrivacyPolicyConfig {
  const PrivacyPolicyConfig._();

  static const hostedPolicyUrl = String.fromEnvironment(
    'YALLA_PRIVACY_POLICY_URL',
    defaultValue: '',
  );
  static const effectiveDate = String.fromEnvironment(
    'YALLA_PRIVACY_EFFECTIVE_DATE',
    defaultValue: 'June 8, 2026',
  );
  static const supportEmail = String.fromEnvironment(
    'YALLA_PRIVACY_SUPPORT_EMAIL',
    defaultValue: '',
  );

  static Uri? get hostedPolicyUri {
    final uri = Uri.tryParse(hostedPolicyUrl.trim());
    if (uri == null || !uri.hasScheme) return null;
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    return uri;
  }
}
