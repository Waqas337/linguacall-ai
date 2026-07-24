import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class FunctionService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<void> processCaption({
    required String roomId,
    required String text,
  }) async {
    try {
      final callable = _functions.httpsCallable('processCaption');

      await callable.call({
        'roomId': roomId,
        'text': text,
      });

      debugPrint('Caption sent successfully: $text');
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Firebase function error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error in processCaption: $e');
      rethrow;
    }
  }
}