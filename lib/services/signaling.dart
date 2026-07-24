import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef StreamStateCallback = void Function(MediaStream stream);

class Signaling {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _callerCandidatesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _calleeCandidatesSub;
String get _meteredUsername {
  final username = dotenv.env['METERED_USERNAME'];

  if (username == null || username.isEmpty) {
    throw Exception('METERED_USERNAME is missing from .env');
  }

  return username;
}

String get _meteredCredential {
  final credential = dotenv.env['METERED_CREDENTIAL'];

  if (credential == null || credential.isEmpty) {
    throw Exception('METERED_CREDENTIAL is missing from .env');
  }

  return credential;
}
  Map<String, dynamic> get configuration => {
    'sdpSemantics': 'unified-plan',
    'iceTransportPolicy': 'all',
    'bundlePolicy': 'max-bundle',
    'rtcpMuxPolicy': 'require',
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ],
      },
      {
        'urls': [
          'turn:a.relay.metered.ca:80',
          'turn:a.relay.metered.ca:80?transport=tcp',
          'turn:a.relay.metered.ca:443',
          'turn:a.relay.metered.ca:443?transport=tcp',
        ],
        'username': '_meteredUsername',
        'credential': '_meteredCredential',
      },
    ],
  };

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  String? roomId;
  String? currentRoomText;
  StreamStateCallback? onAddRemoteStream;
  bool micEnabled = true;
  bool videoEnabled = true;

  final List<RTCIceCandidate> _remoteIceCandidatesBuffer = [];

  Future<void> openUserMedia(
    RTCVideoRenderer localVideo,
    RTCVideoRenderer remoteVideo,
  ) async {
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
       'audio': {
  'echoCancellation': true,
  'noiseSuppression': true,
  'autoGainControl': true,
  'googEchoCancellation': true,
  'googNoiseSuppression': true,
  'googHighpassFilter': true,
  'googAudioMirroring': false,
},
        'video': {
          'width': {'ideal': 640, 'max': 1280},
          'height': {'ideal': 480, 'max': 720},
          'frameRate': {'ideal': 20, 'max': 30},
        },
      });

      localVideo.srcObject = stream;
      localStream = stream;

      micEnabled = true;
      videoEnabled = true;

      print('Local media stream opened');
    } catch (e) {
      print('Error opening camera/mic: $e');
    }
  }

  Future<void> toggleMic() async {
    if (localStream == null) {
      print('toggleMic: localStream is null');
      return;
    }

    micEnabled = !micEnabled;

    for (final audioTrack in localStream!.getAudioTracks()) {
      audioTrack.enabled = micEnabled;
    }

    print('Mic ${micEnabled ? 'UNMUTED' : 'MUTED'}');
  }

  Future<void> toggleCamera() async {
    if (localStream == null) {
      print('toggleCamera: localStream is null');
      return;
    }

    videoEnabled = !videoEnabled;

    for (final videoTrack in localStream!.getVideoTracks()) {
      videoTrack.enabled = videoEnabled;
    }

    print('Camera ${videoEnabled ? 'ON' : 'OFF'}');
  }

  void muteRemoteAudio() {
    if (remoteStream == null) {
      print('muteRemoteAudio: remoteStream is null');
      return;
    }

    for (final track in remoteStream!.getAudioTracks()) {
      track.enabled = false;
    }

    print('Remote audio MUTED');
  }

  void unmuteRemoteAudio() {
    if (remoteStream == null) {
      print('unmuteRemoteAudio: remoteStream is null');
      return;
    }

    for (final track in remoteStream!.getAudioTracks()) {
      track.enabled = true;
    }

    print('Remote audio UNMUTED');
  }

  Future<void> _handleRemoteCandidate(RTCIceCandidate candidate) async {
    if (peerConnection == null) {
      print('PeerConnection is null, buffering candidate');
      _remoteIceCandidatesBuffer.add(candidate);
      return;
    }

    final remoteDesc = await peerConnection!.getRemoteDescription();

    if (remoteDesc == null) {
      print('remoteDescription == null, buffering candidate: ${candidate.toMap()}');
      _remoteIceCandidatesBuffer.add(candidate);
    } else {
      print('Adding remote ICE candidate now: ${candidate.toMap()}');
      try {
        await peerConnection!.addCandidate(candidate);
      } catch (e) {
        print('Error adding remote ICE candidate: $e');
      }
    }
  }

  Future<void> _flushRemoteIceCandidatesBuffer() async {
    if (peerConnection == null) return;
    if (_remoteIceCandidatesBuffer.isEmpty) return;

    final remoteDesc = await peerConnection!.getRemoteDescription();
    if (remoteDesc == null) {
      print('Tried to flush but remoteDescription still null');
      return;
    }

    print('Flushing ${_remoteIceCandidatesBuffer.length} buffered ICE candidates...');
    for (final c in _remoteIceCandidatesBuffer) {
      try {
        await peerConnection!.addCandidate(c);
      } catch (e) {
        print('Error adding buffered ICE candidate: $e');
      }
    }
    _remoteIceCandidatesBuffer.clear();
  }

  void _setupRemoteTrackListener() {
    peerConnection?.onTrack = (RTCTrackEvent event) {
      print('onTrack: ${event.streams.length} streams');
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];
        print('Got remote stream: ${remoteStream!.id}');
        onAddRemoteStream?.call(remoteStream!);
      } else {
        print('onTrack: no streams in event');
      }
    };
  }

  Future<String> createRoom(RTCVideoRenderer remoteRenderer) async {
    final db = FirebaseFirestore.instance;
    final roomRef = db.collection('rooms').doc();

    print('Create PeerConnection with configuration: $configuration');

    peerConnection = await createPeerConnection(configuration);
    _registerPeerConnectionListeners();
    _setupRemoteTrackListener();

    localStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track, localStream!);
    });

    final callerCandidatesCollection = roomRef.collection('callerCandidates');

    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      print('Caller got candidate: ${candidate.toMap()}');
      callerCandidatesCollection.add(candidate.toMap());
    };

    final offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);
    print('Created offer: $offer');

    final roomWithOffer = {
      'offer': offer.toMap(),
    };
    await roomRef.set(roomWithOffer);

    final newRoomId = roomRef.id;
    print('New room created with offer. Room ID: $newRoomId');
    roomId = newRoomId;
    currentRoomText = 'Current room is $newRoomId - You are the caller!';

    await _roomSub?.cancel();
    _roomSub = roomRef.snapshots().listen((snapshot) async {
  print('Got updated room snapshot');
      if (!snapshot.exists) return;

      final data = snapshot.data();
      if (data == null) return;

      final answer = data['answer'];

      if (answer != null) {
        final currentRemoteDesc = await peerConnection?.getRemoteDescription();
        if (currentRemoteDesc == null) {
          final rtcAnswer = RTCSessionDescription(
            answer['sdp'],
            answer['type'],
          );
          print('Caller: setting remote description with answer');
          await peerConnection?.setRemoteDescription(rtcAnswer);
          await _flushRemoteIceCandidatesBuffer();
        }
      }
    });

    await _calleeCandidatesSub?.cancel();
    _calleeCandidatesSub =
        roomRef.collection('calleeCandidates').snapshots().listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          print(
            'Caller got new remote ICE candidate (from callee): ${jsonEncode(data)}',
          );

          final candidate = RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          );

          _handleRemoteCandidate(candidate);
        }
      }
    });

    return newRoomId;
  }

  Future<bool> joinRoom(String roomId, RTCVideoRenderer remoteVideo) async {
    final db = FirebaseFirestore.instance;
    print('Joining room: $roomId');

    final roomRef = db.collection('rooms').doc(roomId);
    final roomSnapshot = await roomRef.get();
    print('Got room ${roomSnapshot.exists}');

    if (!roomSnapshot.exists) {
      print('Room does not exist');
      return false;
    }

    this.roomId = roomId;

    peerConnection = await createPeerConnection(configuration);
    _registerPeerConnectionListeners();
    _setupRemoteTrackListener();

    localStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track, localStream!);
    });

    final calleeCandidatesCollection = roomRef.collection('calleeCandidates');

    peerConnection!.onIceCandidate = (RTCIceCandidate? candidate) {
      if (candidate == null) {
        print('onIceCandidate: complete!');
        return;
      }

      print('Callee onIceCandidate: ${candidate.toMap()}');
      calleeCandidatesCollection.add(candidate.toMap());
    };

    final data = roomSnapshot.data();
    if (data == null) {
      print('Room data is null');
      return false;
    }

    print('Got offer $data');
    final offer = data['offer'];

    if (offer == null) {
      print('Offer is missing in room');
      return false;
    }

    await peerConnection?.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );

    await _flushRemoteIceCandidatesBuffer();

    final answer = await peerConnection!.createAnswer();
    print('Created Answer $answer');
    await peerConnection!.setLocalDescription(answer);

    final roomWithAnswer = {
      'answer': {
        'type': answer.type,
        'sdp': answer.sdp,
      }
    };

    await roomRef.update(roomWithAnswer);

    await _callerCandidatesSub?.cancel();
    _callerCandidatesSub =
        roomRef.collection('callerCandidates').snapshots().listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          print('Callee got new remote ICE candidate (from caller): $data');

          final candidate = RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          );

          _handleRemoteCandidate(candidate);
        }
      }
    });

    return true;
  }

  Future<void> hangUp() async {
    print('Hanging up');

    try {
      final localTracks = localStream?.getTracks() ?? [];
      for (final track in localTracks) {
        track.stop();
      }

      final remoteTracks = remoteStream?.getTracks() ?? [];
      for (final track in remoteTracks) {
        track.stop();
      }

      await peerConnection?.close();
    } catch (e) {
      print('Peer cleanup error: $e');
    }

    try {
      await _roomSub?.cancel();
      await _callerCandidatesSub?.cancel();
      await _calleeCandidatesSub?.cancel();
    } catch (e) {
      print('Listener cancel error: $e');
    }

    if (roomId != null) {
      final db = FirebaseFirestore.instance;
      final roomRef = db.collection('rooms').doc(roomId);

      try {
        final calleeCandidates =
            await roomRef.collection('calleeCandidates').get();
        for (final document in calleeCandidates.docs) {
          await document.reference.delete();
        }

        final callerCandidates =
            await roomRef.collection('callerCandidates').get();
        for (final document in callerCandidates.docs) {
          await document.reference.delete();
        }

        await roomRef.delete();
      } catch (e) {
        print('Room cleanup error: $e');
      }
    }

    try {
      await localStream?.dispose();
    } catch (_) {}

    try {
      await remoteStream?.dispose();
    } catch (_) {}

    remoteStream = null;
    localStream = null;
    peerConnection = null;
    roomId = null;
    currentRoomText = null;
    _remoteIceCandidatesBuffer.clear();
  }

  void _registerPeerConnectionListeners() {
    peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      print('ICE gathering state changed: $state');
    };

    peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      print('Connection state change: $state');
    };

    peerConnection?.onSignalingState = (RTCSignalingState state) {
      print('Signaling state change: $state');
    };

    peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
      print('ICE connection state change: $state');
    };
  }
}