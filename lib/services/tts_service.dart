import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  String _lastSpokenText = '';

  Future<void> init() async {
   
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);

    _tts.setStartHandler(() {
      _isSpeaking = true;
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
    });

    _tts.setErrorHandler((message) {
      _isSpeaking = false;
    });
  }

Future<void> setLanguage(String languageCode) async {
  final mapped = _mapTtsLanguage(languageCode);
  await _tts.setLanguage(mapped);
}

String _mapTtsLanguage(String code) {
  switch (code) {
    case 'ur':
      return 'ur-PK';
    case 'en':
      return 'en-US';
    case 'ar':
      return 'ar-SA';
    case 'fr':
      return 'fr-FR';
    case 'es':
      return 'es-ES';
    case 'it':
      return 'it-IT';
    case 'de':
      return 'de-DE';
    case 'ja':
      return 'ja-JP';
    case 'tr':
      return 'tr-TR';
    case 'zh-Hans':
      return 'zh-CN';
    default:
      return 'en-US';
      
  }
}
  Future<void> speakIfNew(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;
    if (cleaned == _lastSpokenText) return;

    _lastSpokenText = cleaned;

    if (_isSpeaking) {
      await _tts.stop();
    }

    await _tts.speak(cleaned);
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }
}