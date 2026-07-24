import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TranslationService {
  // Yahan apni Google Cloud Translation API key lagao
  static String get _apiKey {
  final key = dotenv.env['GOOGLE_TRANSLATE_API_KEY'];

  if (key == null || key.isEmpty) {
    throw Exception('GOOGLE_TRANSLATE_API_KEY is missing from .env');
  }

  return key;
}

  static const String _translateEndpoint =
      'https://translation.googleapis.com/language/translate/v2';

  static const List<String> _allowedLanguages = [
    'en',
    'ur',
    'ar',
    'fr',
    'es',
    'it',
    'de',
    'ja',
    'tr',
    'zh',
  ];

  String _normalizeLanguageCode(String code) {
    final normalized = code.trim();

    switch (normalized) {
      case 'zh-Hans':
        return 'zh';
      case 'zh-CN':
        return 'zh';
      case 'zh-TW':
        return 'zh';
      default:
        return normalized;
    }
  }

  Future<String> translateText({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return '';

    final normalizedTarget = _normalizeLanguageCode(targetLanguage);
    final normalizedSource = sourceLanguage == null || sourceLanguage.trim().isEmpty
        ? null
        : _normalizeLanguageCode(sourceLanguage);

    try {
      final uri = Uri.parse('$_translateEndpoint?key=$_apiKey');

      final Map<String, dynamic> body = {
        'q': cleaned,
        'target': normalizedTarget,
        'format': 'text',
      };

      if (normalizedSource != null && normalizedSource.isNotEmpty) {
        body['source'] = normalizedSource;
      }

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        print('Google translate error: ${response.body}');
        return cleaned;
      }

      final data = jsonDecode(response.body);

      final translatedText = data['data']?['translations']?[0]?['translatedText']
              ?.toString() ??
          '';

      if (translatedText.trim().isEmpty) {
        return cleaned;
      }

      return translatedText.trim();
    } catch (e) {
      print('Google translate exception: $e');
      return cleaned;
    }
  }

  Future<String> detectLanguage(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return 'en';

    try {
      final uri = Uri.parse('$_translateEndpoint/detect?key=$_apiKey');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'q': cleaned,
        }),
      );

      if (response.statusCode != 200) {
        print('Google detect error: ${response.body}');
        return 'en';
      }

      final data = jsonDecode(response.body);

      final detected = data['data']?['detections']?[0]?[0]?['language']
              ?.toString() ??
          'en';

      final normalizedDetected = _normalizeLanguageCode(detected);

      if (_allowedLanguages.contains(normalizedDetected)) {
        return normalizedDetected;
      }

      return 'en';
    } catch (e) {
      print('Google detect exception: $e');
      return 'en';
    }
  }
}