class SupportedLanguage {
  final String code;
  final String name;

  const SupportedLanguage({
    required this.code,
    required this.name,
  });
}

const List<SupportedLanguage> supportedLanguages = [
  SupportedLanguage(code: 'en', name: 'English'),
  SupportedLanguage(code: 'ur', name: 'Urdu'),
  SupportedLanguage(code: 'ar', name: 'Arabic'),
  SupportedLanguage(code: 'fr', name: 'French'),
  SupportedLanguage(code: 'es', name: 'Spanish'),
  SupportedLanguage(code: 'it', name: 'Italian'),
  SupportedLanguage(code: 'de', name: 'German'),
  SupportedLanguage(code: 'ja', name: 'Japanese'),
  SupportedLanguage(code: 'tr', name: 'Turkish'),
  SupportedLanguage(code: 'zh', name: 'Chinese'),
];