import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/deepgram_service.dart';
import '../services/signaling.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';

class CallScreen extends StatefulWidget {
  final bool isCaller;
  final String? calleeUid;
  final String? roomId;
  final String? callerUid;

  const CallScreen({
    super.key,
    required this.isCaller,
    this.calleeUid,
    this.roomId,
    this.callerUid,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final Signaling _signaling = Signaling();
  final TranslationService _translationService = TranslationService();
  final TtsService _ttsService = TtsService();

  DeepgramService? _deepgram;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  String? _roomId;
  bool _loading = true;
  bool _ended = false;
  String _callStatus = 'ringing';

  String _lastRemoteCaptionDocText = '';
  String _liveIncomingCaption = '';
  String _liveTranslatedCaption = '';
  String _lastRemoteSpokenText = '';
  String _lastDeepgramCaption = '';
  String _lastTranslatedSaved = '';
  String _lastRemoteFinalSpokenText = '';
  bool _lastRemoteWasFinal = false;
  String _lastDetectedSourceLanguage = 'en';

  bool _showEnglish = true;
  bool _showTranslation = true;
  bool _voiceOverOn = true;
  bool _originalVoiceOn = true;

  String _myLanguageCode = 'en';
  String _myLanguageLabel = 'English';

  String _otherUserLanguageCode = 'en';
  String _otherUserLanguageLabel = 'English';

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _liveCaptionSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomStatusSub;

  @override
  void initState() {
    super.initState();
    _ttsService.init();
    _initCall();
  }

  String _mapDeepgramLanguage(String code) {
    switch (code) {
      case 'en':
        return 'en-US';
      case 'ur':
        return 'ur';
      case 'ar':
        return 'ar';
      case 'fr':
        return 'fr';
      case 'es':
        return 'es';
      case 'it':
        return 'it';
      case 'de':
        return 'de';
      case 'ja':
        return 'ja';
      case 'tr':
        return 'tr';
      case 'zh-Hans':
        return 'zh';
      default:
        return 'en-US';
    }
  }

  Future<void> _loadUserLanguagePreferences() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    try {
      final myDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .get(const GetOptions(source: Source.serverAndCache));

      final myData = myDoc.data() ?? {};

      _myLanguageCode =
          (myData['preferredLanguageCode'] ?? 'en').toString().trim();
      _myLanguageLabel =
          (myData['preferredLanguageLabel'] ?? 'English').toString().trim();
// ✅ Settings se captions aur voiceOver load karo
final captionsEnabled = myData['captionsEnabled'] ?? true;
final voiceOverEnabled = myData['voiceOverEnabled'] ?? false;
_showEnglish = captionsEnabled as bool;
_showTranslation = captionsEnabled as bool;
_voiceOverOn = voiceOverEnabled as bool;
      final otherUid = widget.isCaller ? widget.calleeUid : widget.callerUid;

      if (otherUid != null && otherUid.isNotEmpty) {
        final otherDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(otherUid)
            .get(const GetOptions(source: Source.serverAndCache));

        final otherData = otherDoc.data() ?? {};

        _otherUserLanguageCode =
            (otherData['preferredLanguageCode'] ?? 'en').toString().trim();
        _otherUserLanguageLabel =
            (otherData['preferredLanguageLabel'] ?? 'English')
                .toString()
                .trim();
      }

      debugPrint('My language code: $_myLanguageCode');
      debugPrint('My language label: $_myLanguageLabel');
      debugPrint('Other language code: $_otherUserLanguageCode');
      debugPrint('Other language label: $_otherUserLanguageLabel');
    } catch (e) {
      debugPrint('Failed to load language preferences: $e');
    }
  }

  Future<void> _processSpokenCaption(String text, bool isFinal) async {
    if (_roomId == null) return;
if (!isFinal) return;
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;
if (cleaned == _lastDeepgramCaption) return;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    debugPrint(
      'Processing spoken caption | myUid: $myUid | roomId: $_roomId | text: $cleaned | isFinal: $isFinal',
    );

    if (myUid == null || myUid.isEmpty) {
      debugPrint('Caption save blocked because myUid empty');
      return;
    }

    if (!isFinal && cleaned == _lastDeepgramCaption) {
      return;
    }

    _lastDeepgramCaption = cleaned;

    try {
      final detectedLang =
    _myLanguageCode.trim().isEmpty ? 'en' : _myLanguageCode.trim();

_lastDetectedSourceLanguage = detectedLang;

      final targetLang =
          _otherUserLanguageCode.trim().isEmpty ? 'en' : _otherUserLanguageCode.trim();

      String translated = cleaned;

      if (detectedLang != targetLang) {
        translated = await _translationService.translateText(
          text: cleaned,
          sourceLanguage: detectedLang,
          targetLanguage: targetLang,
        );
      }

      translated = translated.trim().isEmpty ? cleaned : translated.trim();

      if (!isFinal && _lastTranslatedSaved == translated) {
        return;
      }

      _lastTranslatedSaved = translated;

      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(_roomId)
          .collection('liveCaption')
          .doc(myUid)
          .set({
        'speakerUid': myUid,
        'originalText': cleaned,
        'translatedText': translated,
        'sourceLanguage': detectedLang,
        'targetLanguage': targetLang,
        'isFinal': isFinal,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint(
        'Saved caption doc => speakerUid: $myUid | original: $cleaned | translated: $translated | isFinal: $isFinal',
      );
    } catch (e) {
      debugPrint('Caption processing error: $e');
    }
  }

  Future<void> _clearCurrentCaption() async {
    if (_roomId == null) return;

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(_roomId)
          .collection('liveCaption')
          .doc(myUid)
          .delete();

      _lastDeepgramCaption = '';
      _lastTranslatedSaved = '';
      _lastRemoteSpokenText = '';
      _lastRemoteFinalSpokenText = '';
      _lastRemoteWasFinal = false;
      _lastRemoteCaptionDocText = '';

      if (mounted) {
        setState(() {
          _liveIncomingCaption = '';
          _liveTranslatedCaption = '';
        });
      }
    } catch (e) {
      debugPrint('Failed to clear caption: $e');
    }
  }

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  String? get _otherUid {
  final myUid = _myUid;

  // ✅ Caller side: calleeUid use karo
  // ✅ Callee side: callerUid use karo (calleeUid pass nahi hota ab)
  final other = widget.isCaller ? widget.calleeUid : widget.callerUid;

  if (other == null || other.trim().isEmpty) {
    debugPrint('_otherUid is null or empty');
    return null;
  }

  if (myUid != null && other.trim() == myUid.trim()) {
    debugPrint('Blocked _otherUid because it matched myUid: $myUid');
    return null;
  }

  return other.trim();
}

  void _listenForLiveCaption() {
    if (_roomId == null) return;

    final myUid = _myUid;
    final otherUid = _otherUid;

    debugPrint('=== CAPTION LISTENER START ===');
    debugPrint('isCaller: ${widget.isCaller}');
    debugPrint('myUid: $myUid');
    debugPrint('otherUid: $otherUid');
    debugPrint('calleeUid widget: ${widget.calleeUid}');
    debugPrint('callerUid widget: ${widget.callerUid}');
    debugPrint('roomId: $_roomId');

    if (myUid == null || myUid.isEmpty) {
      debugPrint('My uid missing, cannot listen for captions');
      return;
    }

    if (otherUid == null || otherUid.isEmpty) {
      debugPrint('Other user uid missing, cannot listen for remote captions');
      return;
    }

    if (otherUid == myUid) {
      debugPrint('Other uid is same as my uid, blocking self-caption listener');
      return;
    }

    _liveCaptionSub?.cancel();

    _liveCaptionSub = FirebaseFirestore.instance
        .collection('rooms')
        .doc(_roomId)
        .collection('liveCaption')
        .doc(otherUid)
        .snapshots()
        .listen((snapshot) async {
      if (!mounted) return;

      if (!snapshot.exists) {
        debugPrint('Remote caption doc does not exist for otherUid: $otherUid');

        _lastRemoteSpokenText = '';
        _lastRemoteFinalSpokenText = '';
        _lastRemoteCaptionDocText = '';
        _lastRemoteWasFinal = false;

        if (!mounted) return;
        setState(() {
          _liveIncomingCaption = '';
          _liveTranslatedCaption = '';
        });
        return;
      }

      if (snapshot.id != otherUid) {
        debugPrint('Ignoring caption doc because snapshot.id != otherUid');
        return;
      }

      final data = snapshot.data();
      if (data == null) return;

      final speakerUid = (data['speakerUid'] ?? '').toString().trim();
      final otherOriginal = (data['originalText'] ?? '').toString().trim();
      final otherTranslated = (data['translatedText'] ?? '').toString().trim();
      final isFinal = data['isFinal'] == true;

      debugPrint(
        'Caption snapshot => docId: ${snapshot.id}, speakerUid: $speakerUid, myUid: $myUid, otherUid: $otherUid, isFinal: $isFinal',
      );

      if (speakerUid.isEmpty) {
        debugPrint('Ignoring caption because speakerUid empty');
        return;
      }

      if (speakerUid == myUid) {
        debugPrint('Ignoring SELF caption');
        return;
      }

      if (speakerUid != otherUid) {
        debugPrint('Ignoring caption because speakerUid != otherUid');
        return;
      }

      if (otherOriginal.isEmpty && otherTranslated.isEmpty) {
        debugPrint('Ignoring caption because both texts are empty');
        return;
      }

      final remoteDocKey = '$otherOriginal|||$otherTranslated|||$isFinal';

      if (_lastRemoteCaptionDocText == remoteDocKey) {
        debugPrint('Skipping duplicate remote caption snapshot');
        return;
      }

      _lastRemoteCaptionDocText = remoteDocKey;

      if (!mounted) return;

      setState(() {
        _liveIncomingCaption = otherOriginal;
        _liveTranslatedCaption = otherTranslated;
      });

     if (_voiceOverOn && otherTranslated.isNotEmpty && isFinal) {
  if (_lastRemoteFinalSpokenText != otherTranslated) {
    _lastRemoteFinalSpokenText = otherTranslated;
    _signaling.muteRemoteAudio();
    await _ttsService.setLanguage(_myLanguageCode);
    await _ttsService.speakIfNew(otherTranslated);
    if (_originalVoiceOn) {
      _signaling.unmuteRemoteAudio();
    }
  }
}

      _lastRemoteWasFinal = isFinal;
    });
  }

  void _listenForCallEnd() {
    if (_roomId == null) return;

    _roomStatusSub?.cancel();

   _roomStatusSub = FirebaseFirestore.instance
    .collection('rooms')
    .doc(_roomId)
    .snapshots()
    .listen((snapshot) async {
  if (!snapshot.exists) {
    if (!_ended) {
      debugPrint('Room deleted — remote ended the call');
      await _endCall(notifyRemote: false);
    }
    return;
  }

  final data = snapshot.data();
  if (data == null) return;

  final status = (data['callStatus'] ?? '').toString().trim();

  if (mounted && status.isNotEmpty) {
    setState(() {
      _callStatus = status;
    });
  }

  // ✅ Agar callStatus ended ho toh bhi call end karo
  if (status == 'ended' && !_ended) {
    debugPrint('callStatus ended — remote ended the call');
    await _endCall(notifyRemote: false);
  }
});
  }

  Future<void> _saveRecentCall() async {
    final myUid = _myUid;
    final otherUid = _otherUid;

    if (myUid == null || myUid.isEmpty) return;
    if (otherUid == null || otherUid.isEmpty) return;

    try {
      final otherDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(otherUid)
          .get();

      final otherData = otherDoc.data() ?? {};

      await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('recentCalls')
          .doc(otherUid)
          .set({
        'otherUid': otherUid,
        'otherName': (otherData['name'] ?? 'Unknown').toString(),
        'otherNumber': (otherData['number'] ?? '').toString(),
        'lastCallTime': FieldValue.serverTimestamp(),
        'callType': 'audio_video',
      }, SetOptions(merge: true));

      debugPrint('Recent call saved for $myUid with $otherUid');
    } catch (e) {
      debugPrint('Failed to save recent call: $e');
    }
  }

  Future<void> _initCall() async {
    await _loadUserLanguagePreferences();

    debugPrint('CallScreen init => isCaller: ${widget.isCaller}');
    debugPrint('CallScreen init => myUid: $_myUid');
    debugPrint('CallScreen init => calleeUid: ${widget.calleeUid}');
    debugPrint('CallScreen init => callerUid: ${widget.callerUid}');
    debugPrint('CallScreen init => computed otherUid: $_otherUid');
    debugPrint('CallScreen init => myLanguageCode: $_myLanguageCode');
    debugPrint('CallScreen init => otherLanguageCode: $_otherUserLanguageCode');

    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
final deepgramApiKey = dotenv.env['DEEPGRAM_API_KEY'];

if (deepgramApiKey == null || deepgramApiKey.isEmpty) {
  throw Exception('DEEPGRAM_API_KEY is missing');
}


    _deepgram = DeepgramService(
      apiKey: deepgramApiKey,
      language: _mapDeepgramLanguage(_myLanguageCode),
      onTranscript: (text, isFinal) async {
        debugPrint(
          'Deepgram transcript received => text: "$text" | isFinal: $isFinal | isCaller: ${widget.isCaller} | myUid: $_myUid | otherUid: $_otherUid',
        );
        await _processSpokenCaption(text, isFinal);
      },
    );

    _signaling.onAddRemoteStream = (stream) {
      if (!mounted) return;
      setState(() {
        _remoteRenderer.srcObject = stream;
      });
    };

    await _signaling.openUserMedia(_localRenderer, _remoteRenderer);

    if (widget.isCaller) {
      final roomId = await _signaling.createRoom(_remoteRenderer);
      if (!mounted) return;

      setState(() {
        _roomId = roomId;
        _loading = false;
        _callStatus = 'ringing';
      });

      _listenForCallEnd();

     await FirebaseFirestore.instance
    .collection('rooms')
    .doc(roomId)
    .set({
  'callStatus': 'ringing',
}, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _liveIncomingCaption = '';
          _liveTranslatedCaption = '';
          _lastRemoteSpokenText = '';
          _lastRemoteFinalSpokenText = '';
          _lastRemoteCaptionDocText = '';
          _lastRemoteWasFinal = false;
        });
      }

      await _clearCurrentCaption();
      _listenForLiveCaption();

      try {
        await _deepgram?.start();
      } catch (e) {
        debugPrint('Caller Deepgram start failed: $e');
      }

      if (widget.calleeUid != null) {
        final myUid = FirebaseAuth.instance.currentUser!.uid;
        final myDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(myUid)
            .get();

        final myNumber = myDoc.data()?['number'];

        await FirebaseFirestore.instance
            .collection('calls')
            .doc(widget.calleeUid)
            .set({
          'fromUid': myUid,
          'fromNumber': myNumber,
          'roomId': roomId,
          'status': 'ringing',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
    } else {
      if (widget.roomId == null) {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
        return;
      }

      final joined = await _signaling.joinRoom(widget.roomId!, _remoteRenderer);
      if (!mounted) return;

      if (!joined) {
        setState(() {
          _loading = false;
        });
        return;
      }

      setState(() {
        _roomId = widget.roomId;
        _loading = false;
        _callStatus = 'connected';
      });

      _listenForCallEnd();

      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .set({
        'callStatus': 'connected',
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _liveIncomingCaption = '';
          _liveTranslatedCaption = '';
          _lastRemoteSpokenText = '';
          _lastRemoteFinalSpokenText = '';
          _lastRemoteCaptionDocText = '';
          _lastRemoteWasFinal = false;
        });
      }

      await _clearCurrentCaption();
      _listenForLiveCaption();

      try {
        await _deepgram?.start();
      } catch (e) {
        debugPrint('Callee Deepgram start failed: $e');
      }
    }
  }

  Future<void> _endCall({bool notifyRemote = true}) async {
    if (_ended) return;
    _ended = true;

    final roomId = _roomId;

    if (mounted) {
      Navigator.of(context).pop();
    }

    Future(() async {
      try {
        if (notifyRemote && roomId != null) {
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(roomId)
              .set({
            'callStatus': 'ended',
            'endedAt': FieldValue.serverTimestamp(),
            'endedBy': _myUid,
          }, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('Failed to notify remote about end call: $e');
      }
// ✅ calls doc bhi delete karo taake dobara notification na aaye
  try {
    final myUid = _myUid;
    final otherUid = _otherUid;
    if (myUid != null) {
      await FirebaseFirestore.instance
          .collection('calls')
          .doc(myUid)
          .delete();
    }
    if (otherUid != null) {
      await FirebaseFirestore.instance
          .collection('calls')
          .doc(otherUid)
          .delete();
    }
  } catch (e) {
    debugPrint('calls doc delete error: $e');
  }
      try {
        await _deepgram?.stop();
      } catch (e) {
        debugPrint('Deepgram stop error: $e');
      }

      try {
        await _ttsService.stop();
      } catch (e) {
        debugPrint('TTS stop error: $e');
      }

      try {
        await _clearCurrentCaption();
      } catch (e) {
        debugPrint('Clear caption error: $e');
      }

      try {
        await _signaling.hangUp();
      } catch (e) {
        debugPrint('Signaling hangup error: $e');
      }

      try {
        await _saveRecentCall();
      } catch (e) {
        debugPrint('Recent call save error: $e');
      }

      try {
        await _liveCaptionSub?.cancel();
        await _roomStatusSub?.cancel();
      } catch (e) {
        debugPrint('Subscription cancel error: $e');
      }
    });
  }

  PopupMenuItem<String> _menuItem(String value, bool enabled, String title) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white)),
          Icon(
            enabled ? Icons.toggle_on : Icons.toggle_off,
            color: enabled ? Colors.green : Colors.grey,
            size: 28,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _liveCaptionSub?.cancel();
    _roomStatusSub?.cancel();

    try {
      _deepgram?.dispose();
    } catch (_) {}

    _ttsService.stop();

    try {
      _localRenderer.dispose();
      _remoteRenderer.dispose();
    } catch (_) {}

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMicOn = _signaling.micEnabled;
    final isVideoOn = _signaling.videoEnabled;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
  _callStatus == 'connected' 
    ? 'Connected ✓' 
    : _callStatus == 'ringing' 
      ? 'Calling…' 
      : 'In Call',
),
        backgroundColor: Colors.black,
        actions: [
          PopupMenuButton<String>(
            color: Colors.black87,
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              setState(() {
                if (value == 'english') {
                  _showEnglish = !_showEnglish;
                } else if (value == 'translation') {
                  _showTranslation = !_showTranslation;
                } else if (value == 'voiceover') {
                  _voiceOverOn = !_voiceOverOn;
                } else if (value == 'original') {
                  _originalVoiceOn = !_originalVoiceOn;
                }
              });

              if (value == 'voiceover' && !_voiceOverOn) {
                await _ttsService.stop();
              }

              if (value == 'original') {
                if (_originalVoiceOn) {
                  _signaling.unmuteRemoteAudio();
                } else {
                  _signaling.muteRemoteAudio();
                }
              }
            },
            itemBuilder: (context) => [
              _menuItem('english', _showEnglish, 'English Captions'),
              _menuItem('translation', _showTranslation, 'Translated Captions'),
              _menuItem('voiceover', _voiceOverOn, 'Voice Over'),
              _menuItem('original', _originalVoiceOn, 'Original Voice'),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
                Positioned(
                  right: 16,
                  top: 16,
                  width: 120,
                  height: 160,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: RTCVideoView(
                        _localRenderer,
                        mirror: true,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 120,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity:
                        (_liveIncomingCaption.isEmpty &&
                                _liveTranslatedCaption.isEmpty)
                            ? 0.75
                            : 1.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_showEnglish)
                            Text(
                              _liveIncomingCaption.isEmpty
                                  ? 'Incoming captions will appear here'
                                  : _liveIncomingCaption,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _liveIncomingCaption.isEmpty
                                    ? Colors.white70
                                    : Colors.white,
                                fontSize: 15,
                                height: 1.35,
                              ),
                            ),
                          if (_showEnglish && _showTranslation)
                            const SizedBox(height: 8),
                          if (_showTranslation)
                            Text(
                              _liveTranslatedCaption.isEmpty
                                  ? 'Translated captions will appear here'
                                  : _liveTranslatedCaption,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _liveTranslatedCaption.isEmpty
                                    ? Colors.white60
                                    : Colors.greenAccent,
                                fontSize: 16,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_loading)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _circleBtn(
                  icon: isMicOn ? Icons.mic : Icons.mic_off,
                  color: isMicOn ? Colors.green : Colors.grey,
                  onTap: () async {
                    await _signaling.toggleMic();
                    if (mounted) setState(() {});
                  },
                ),
                _circleBtn(
                  icon: Icons.call_end,
                  color: Colors.red,
                  size: 64,
                  onTap: () {
                    _endCall();
                  },
                ),
                _circleBtn(
                  icon: isVideoOn ? Icons.videocam : Icons.videocam_off,
                  color: isVideoOn ? Colors.green : Colors.grey,
                  onTap: () async {
                    await _signaling.toggleCamera();
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required Color color,
    double size = 56,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}