import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:web_socket_channel/io.dart';

class DeepgramService {
  final String apiKey;
  final void Function(String text, bool isFinal)? onTranscript;
final String? language;
  final AudioRecorder _recorder = AudioRecorder();

  IOWebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _audioSub;
  StreamSubscription? _wsSub;

  bool _started = false;

  DeepgramService({
    required this.apiKey,
    this.language,
    this.onTranscript,
  });

  Future<void> start() async {
    if (_started) return;
    _started = true;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _started = false;
      throw Exception('Microphone permission denied');
    }

   final uri = Uri.parse(
  'wss://api.deepgram.com/v1/listen'
  '?model=nova-3'
  '${language != null && language!.isNotEmpty ? '&language=$language' : ''}'
  '&encoding=linear16'
  '&sample_rate=16000'
  '&channels=1'
  '&interim_results=true'
  '&endpointing=300'
  '&smart_format=true'
  '&punctuate=true',
);

    _channel = IOWebSocketChannel.connect(
      uri,
      headers: {
        'Authorization': 'Token $apiKey',
      },
    );

    _wsSub = _channel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message as String);

          if (data['type'] == 'Results') {
            final transcript = (data['channel']?['alternatives']?[0]?['transcript'] ?? '')
                .toString()
                .trim();

            final isFinal = data['is_final'] == true;

            if (transcript.isNotEmpty) {
              onTranscript?.call(transcript, isFinal);
            }
          }
        } catch (_) {}
      },
      onError: (error) {
        // optional debug
      },
      onDone: () {
        // optional debug
      },
      cancelOnError: false,
    );

    final audioStream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    _audioSub = audioStream.listen(
      (Uint8List chunk) {
        _channel?.sink.add(chunk);
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;

    await _audioSub?.cancel();
    _audioSub = null;

    await _wsSub?.cancel();
    _wsSub = null;

    try {
      await _recorder.stop();
    } catch (_) {}

    try {
      _channel?.sink.add(jsonEncode({'type': 'CloseStream'}));
    } catch (_) {}

    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    await stop();
    _recorder.dispose();
  }
}