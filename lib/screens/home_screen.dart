import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'call_screen.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'sign_in_screen.dart';
import 'chat_screen.dart';
import 'chat_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _myNumber;
  bool _loadingNumber = true;
  String? _userName;
  String _photoUrl = '';
  int _selectedIndex = 0;
bool _incomingDialogShowing = false;
  final TextEditingController _dialController = TextEditingController();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _incomingCallSub;

  @override
  void initState() {
    super.initState();
    _setupUserNumber();
    _loadUserData();
    _setupIncomingCallListener();
    _saveFcmToken();
    _setupFcmListener();
  }

  @override
  void dispose() {
    _incomingCallSub?.cancel();
    _dialController.dispose();
    super.dispose();
  }

  // ── User Data ─────────────────────────────────────────────────────────────

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    if (data != null && mounted) {
      setState(() {
        _userName = data['name'] ?? 'User';
        _myNumber = data['number'] ?? '';
        _photoUrl = data['photoUrl'] ?? '';
      });
    }
  }

  Future<void> _setupUserNumber() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      setState(() => _loadingNumber = false);
      return;
    }
    try {
      final usersRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final numbersRef = FirebaseFirestore.instance.collection('numbers');
      final userSnap = await usersRef.get(const GetOptions(source: Source.serverAndCache));
      String? number;
      if (userSnap.exists && userSnap.data()?['number'] != null) {
        number = userSnap.data()!['number'].toString();
        try {
          final numDoc = await numbersRef.doc(number).get(const GetOptions(source: Source.serverAndCache));
          if (!numDoc.exists) await numbersRef.doc(number).set({'uid': uid});
        } catch (e) {
          debugPrint('numbers sync failed: $e');
        }
      } else {
        number = await _generateUniqueNumber(uid);
        await usersRef.set({'number': number}, SetOptions(merge: true));
        try {
          await numbersRef.doc(number).set({'uid': uid});
        } catch (e) {
          debugPrint('numbers create failed: $e');
        }
      }
      if (!mounted) return;
      setState(() {
        _myNumber = number;
        _loadingNumber = false;
      });
    } catch (e) {
      debugPrint('_setupUserNumber failed: $e');
      if (!mounted) return;
      setState(() => _loadingNumber = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firestore unavailable. Check internet and try again.')),
      );
    }
  }

  Future<String> _generateUniqueNumber(String uid) async {
    final numbersRef = FirebaseFirestore.instance.collection('numbers');
    final random = Random();
    for (int i = 0; i < 20; i++) {
      final number = (100000 + random.nextInt(900000)).toString();
      try {
        final doc = await numbersRef.doc(number).get(const GetOptions(source: Source.serverAndCache));
        if (!doc.exists) {
          await numbersRef.doc(number).set({'uid': uid});
          return number;
        }
      } catch (e) {
        debugPrint('_generateUniqueNumber error: $e');
      }
    }
    throw Exception('Failed to generate unique number');
  }

  // ── Format Helpers ────────────────────────────────────────────────────────

  String _formatCallTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  String _formatCallDate(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final callDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(callDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
void _setupFcmListener() {
  // ✅ App foreground mein ho tab
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (!mounted) return;
    final data = message.data;
    if (data['type'] != 'incoming_call') return;
    
    final fromUid = data['fromUid'] ?? '';
    final fromNumber = data['fromNumber'] ?? 'Unknown';
    final roomId = data['roomId'] ?? '';
    
    if (roomId.isEmpty || fromUid.isEmpty) return;
    if (_incomingDialogShowing) return;
    _showIncomingCallDialog(
      fromUid: fromUid,
      fromNumber: fromNumber,
      roomId: roomId,
    );
  });

  // ✅ App background mein ho, notification tap karke aaye tab
  // ✅ App background se notification tap karke aaye tab
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    if (!mounted) return;
    final data = message.data;
    if (data['type'] != 'incoming_call') return;
    final fromUid = data['fromUid'] ?? '';
    final fromNumber = data['fromNumber'] ?? 'Unknown';
    final roomId = data['roomId'] ?? '';
    if (roomId.isEmpty || fromUid.isEmpty) return;
    if (_incomingDialogShowing) return;
    _showIncomingCallDialog(
      fromUid: fromUid,
      fromNumber: fromNumber,
      roomId: roomId,
    );
  });

}

  String _normalizeNumber(String value) => value.replaceAll(RegExp(r'\s+'), '').trim();


Future<void> _saveFcmToken() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
      debugPrint('FCM Token saved: $token');
    }
  } catch (e) {
    debugPrint('FCM token save failed: $e');
  }
}
  // ── Incoming Call ─────────────────────────────────────────────────────────

  void _setupIncomingCallListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _incomingCallSub = FirebaseFirestore.instance
        .collection('calls')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data();
      if (data == null) return;
      final status = data['status'] as String? ?? 'ringing';
      if (status != 'ringing') return;
      final fromNumber = data['fromNumber'] as String? ?? 'Unknown';
      final roomId = data['roomId'] as String? ?? '';
      final fromUid = data['fromUid'] as String? ?? '';
      if (roomId.isEmpty || fromUid.isEmpty) return;
if (!mounted) return;
if (_incomingDialogShowing) return;
_showIncomingCallDialog(fromUid: fromUid, fromNumber: fromNumber, roomId: roomId);    });
  }

  void _showIncomingCallDialog({
    required String fromUid,
    required String fromNumber,
    required String roomId,
  }) {
    _incomingDialogShowing = true; 
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: const Color(0xFFFFF6F7),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70, height: 70,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF7B2FBE), Color(0xFFE91E8C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(3),
                child: const CircleAvatar(
                  backgroundColor: Color(0xFFEEDDDD),
                  child: Icon(Icons.person, size: 32, color: Colors.black54),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Incoming Call',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87)),
              const SizedBox(height: 6),
              Text(fromNumber,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFFD93BFF), letterSpacing: 3)),
              const SizedBox(height: 4),
              const Text('is calling you...', style: TextStyle(fontSize: 13, color: Colors.black45)),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await _saveRecentCall(otherUid: fromUid, otherNumber: fromNumber, direction: 'missed', callType: 'video');
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null) {
                          await FirebaseFirestore.instance.collection('calls').doc(uid).delete();
                        }
                        _incomingDialogShowing = false; // ✅ ADD
                        if (mounted) Navigator.of(ctx).pop();
                      },
                      icon: const Icon(Icons.call_end_rounded, color: Colors.white, size: 18),
                      label: const Text('Reject', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
  await _saveRecentCall(otherUid: fromUid, otherNumber: fromNumber, direction: 'incoming', callType: 'video');
  final myUid = FirebaseAuth.instance.currentUser?.uid;
  if (myUid != null) {
    await FirebaseFirestore.instance.collection('calls').doc(myUid).delete();
  }
  _incomingDialogShowing = false; // ✅ ADD
  if (mounted) Navigator.of(ctx).pop();
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => CallScreen(
      isCaller: false,
      roomId: roomId,
      callerUid: fromUid,
      // ✅ calleeUid bilkul pass mat karo callee side pe
    ),
  ));
},
                      icon: const Icon(Icons.call_rounded, color: Colors.white, size: 18),
                      label: const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Outgoing Call ─────────────────────────────────────────────────────────

  Future<void> _startCall() async {
    final dialNumber = _dialController.text.replaceAll(RegExp(r'\s+'), '').trim();
    if (dialNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a number')));
      return;
    }
    if (_myNumber != null && dialNumber == _myNumber) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You can't call yourself.")));
      return;
    }
    try {
      final numbersRef = FirebaseFirestore.instance.collection('numbers');
      final numberDoc = await numbersRef.doc(dialNumber).get(const GetOptions(source: Source.serverAndCache));
      if (!numberDoc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found')));
        return;
      }
      final calleeUid = numberDoc.data()?['uid']?.toString() ?? '';
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (calleeUid.isEmpty || currentUid.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UID missing')));
        return;
      }
      await _saveRecentCall(otherUid: calleeUid, otherNumber: dialNumber, direction: 'outgoing', callType: 'video');
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CallScreen(isCaller: true, calleeUid: calleeUid, callerUid: currentUid),
      ));
    } catch (e) {
      debugPrint('_startCall failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not connect. Try again.')));
    }
  }

  void _showDialDialog(BuildContext context) {
    _dialController.clear();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: const Color(0xFFFFF6F7),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF7B2FBE), Color(0xFFE91E8C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.dialpad_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              const Text('Enter Number', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87)),
              const SizedBox(height: 6),
              const Text('Enter the 6-digit number to call', style: TextStyle(fontSize: 13, color: Colors.black45)),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFDA3AE8), width: 1.8),
                ),
                child: TextField(
                  controller: _dialController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 6, color: Colors.black87),
                  decoration: const InputDecoration(
                    hintText: '• • • • • •',
                    hintStyle: TextStyle(fontSize: 22, color: Colors.black26, letterSpacing: 6),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  maxLength: 6,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFDA3AE8), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFFDA3AE8), fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7B2FBE), Color(0xFFE91E8C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ElevatedButton(
                       onPressed: () async {
  final number = _dialController.text.trim();
  Navigator.of(ctx).pop();
  if (number.isNotEmpty) {
    await _startCall();
  }
},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.call_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text('Call', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Save Helpers ──────────────────────────────────────────────────────────

  Future<void> _saveRecentCall({
    required String otherUid,
    required String otherNumber,
    required String direction,
    required String callType,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final cleanNumber = otherNumber.replaceAll(RegExp(r'\s+'), '').trim();
    if (cleanNumber.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('recentCalls').add({
        'otherUid': otherUid,
        'otherNumber': cleanNumber,
        'direction': direction,
        'callType': callType,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to save recent call: $e');
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SignInScreen()), (route) => false);
  }

  // ── UI Widgets ────────────────────────────────────────────────────────────

  Widget _startCallCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDialDialog(context),
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/images/card_startcall.png', fit: BoxFit.cover),
              Container(color: Colors.white.withOpacity(0.03)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentCallsSection() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Text('Recent Calls', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black87)),
            SizedBox(width: 8),
            Text('→ View', style: TextStyle(fontSize: 15, color: Colors.black45)),
          ]),
          const SizedBox(height: 14),
          FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
  future: FirebaseFirestore.instance.collection('users').doc(uid).collection('contacts').get(),
  builder: (context, contactsSnapshot) {
    final Map<String, String> contactsMap = {};
    if (contactsSnapshot.hasData) {
      for (final doc in contactsSnapshot.data!.docs) {
        final d = doc.data();
        final name = (d['savedName'] ?? '').toString().trim();
        final number = _normalizeNumber((d['number'] ?? '').toString());
        if (name.isNotEmpty && number.isNotEmpty) contactsMap[number] = name;
      }
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('recentCalls')
                    .orderBy('createdAt', descending: true)
                    .limit(30)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()));
                  }
                  if (snapshot.hasError) {
                    return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Failed to load recent calls', style: TextStyle(color: Colors.redAccent)));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No recent calls yet', style: TextStyle(fontSize: 15, color: Colors.black54)));
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    separatorBuilder: (_, __) => const Divider(height: 22),
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final direction = (data['direction'] ?? '').toString();
                      final createdAt = data['createdAt'] as Timestamp?;
                      final otherNumber = _normalizeNumber((data['otherNumber'] ?? '').toString());
                      final savedName = contactsMap[otherNumber];
                      final isSaved = savedName != null && savedName.isNotEmpty;
                      final displayTitle = isSaved ? savedName : otherNumber;

                      return Row(
                        children: [
                          const CircleAvatar(
                            radius: 24,
                            backgroundColor: Color(0xFFEBDDDD),
                            child: Icon(Icons.person, color: Colors.black54),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayTitle.isEmpty ? 'Unknown' : displayTitle,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: direction == 'missed' ? Colors.redAccent : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isSaved ? '$otherNumber • $direction' : direction,
                                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                                ),
                                Text(
                                  '${_formatCallDate(createdAt)}  ${_formatCallTime(createdAt)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            direction == 'missed' ? Icons.call_missed : direction == 'incoming' ? Icons.call_received : Icons.call_made,
                            size: 18,
                            color: direction == 'missed' ? Colors.redAccent : Colors.black45,
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () {
                              _dialController.text = otherNumber;
                              _startCall();
                            },
                            icon: const Icon(Icons.call, color: Colors.black87, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 4),
IconButton(
  onPressed: () async {
    final numberDoc = await FirebaseFirestore.instance
        .collection('numbers')
        .doc(otherNumber)
        .get();
    final realUid = numberDoc.data()?['uid']?.toString() ?? '';
    if (realUid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          otherUid: realUid,
          otherName: displayTitle.isEmpty ? otherNumber : displayTitle,
          otherNumber: otherNumber,
        ),
      ),
    );
  },
  icon: const Icon(Icons.chat_bubble_outline_rounded,
      color: Color(0xFFDA3AE8), size: 20),
  padding: EdgeInsets.zero,
  constraints: const BoxConstraints(),
),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.black54, size: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            onSelected: (value) async {
                              if (value == 'add_contact') {
                                final nameCtrl = TextEditingController();
                                await showDialog(
                                  context: context,
                                  builder: (ctx) => Dialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                    backgroundColor: const Color(0xFFFFF6F7),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 52, height: 52,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: LinearGradient(
                                                colors: [Color(0xFF7B2FBE), Color(0xFFE91E8C)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                            child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 26),
                                          ),
                                          const SizedBox(height: 14),
                                          const Text('Add to Contacts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                          const SizedBox(height: 16),
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: const Color(0xFFDA3AE8), width: 1.5),
                                            ),
                                            child: TextField(
                                              controller: nameCtrl,
                                              decoration: const InputDecoration(
                                                hintText: 'Enter Name',
                                                prefixIcon: Icon(Icons.person_outline, color: Color(0xFFDA3AE8)),
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.6),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: Colors.black12, width: 1.5),
                                            ),
                                            child: TextField(
                                              readOnly: true,
                                              controller: TextEditingController(text: otherNumber),
                                              style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.w600),
                                              decoration: const InputDecoration(
                                                prefixIcon: Icon(Icons.dialpad_rounded, color: Colors.black38),
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: () => Navigator.of(ctx).pop(),
                                                  style: OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                                    side: const BorderSide(color: Color(0xFFDA3AE8), width: 1.5),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                  ),
                                                  child: const Text('Cancel', style: TextStyle(color: Color(0xFFDA3AE8), fontWeight: FontWeight.w600)),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    gradient: const LinearGradient(
                                                      colors: [Color(0xFF7B2FBE), Color(0xFFE91E8C)],
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                    ),
                                                    borderRadius: BorderRadius.circular(14),
                                                  ),
                                                  child: ElevatedButton(
                                                    onPressed: () async {
                                                      final name = nameCtrl.text.trim();
                                                      if (name.isEmpty) return;
                                                      final uid = FirebaseAuth.instance.currentUser?.uid;
                                                      if (uid == null) return;
                                                      await FirebaseFirestore.instance
                                                          .collection('users')
                                                          .doc(uid)
                                                          .collection('contacts')
                                                          .add({
                                                        'savedName': name,
                                                        'number': otherNumber,
                                                        'favorite': false,
                                                        'createdAt': FieldValue.serverTimestamp(),
                                                        'updatedAt': FieldValue.serverTimestamp(),
                                                      });
                                                      if (!ctx.mounted) return;
                                                      Navigator.of(ctx).pop();
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Contact saved!')),
                                                        );
                                                      }
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.transparent,
                                                      shadowColor: Colors.transparent,
                                                      padding: const EdgeInsets.symmetric(vertical: 13),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                      elevation: 0,
                                                    ),
                                                    child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              } else if (value == 'delete') {
                                final uid = FirebaseAuth.instance.currentUser?.uid;
                                if (uid != null) {
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(uid)
                                      .collection('recentCalls')
                                      .doc(docs[index].id)
                                      .delete();
                                }
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'add_contact',
                                child: Row(children: [
                                  Icon(Icons.person_add_outlined, color: Color(0xFFDA3AE8), size: 20),
                                  SizedBox(width: 10),
                                  Text('Add to Contacts'),
                                ]),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  SizedBox(width: 10),
                                  Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                ]),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Bottom Nav ────────────────────────────────────────────────────────────

  Widget _buildCenterCallButton() {
    return GestureDetector(
      onTap: () => _showDialDialog(context),
      child: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.pink.withOpacity(0.22), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: ClipOval(child: SvgPicture.asset('assets/images/Floating_button.svg', fit: BoxFit.cover)),
      ),
    );
  }

  Widget _buildCustomBottomNav() {
    return Container(
      height: 72,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BottomNavPainter(),
              child: Container(
padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNavTab(index: 0, label: 'Home', iconPath: 'assets/images/homeicon.png'),
                    _buildNavTab(index: 1, label: 'Contacts', iconPath: 'assets/images/contact_icon.png'),
                    const SizedBox(width: 40),
                    _buildNavTab(index: 2, label: 'Chats', iconPath: 'assets/images/chat_icon.png'),
                    _buildNavTab(index: 3, label: 'Settings', iconPath: 'assets/images/settingicon.png'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTab({required int index, required String label, required String iconPath}) {
    final bool isActive = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == 0) { setState(() => _selectedIndex = 0); return; }
        if (index == 1) { Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactsScreen())); return; }
        if (index == 2) { Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen())); return; }
        if (index == 3) { Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); return; }
},
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                isActive ? const Color(0xFFD93BFF) : const Color(0xFF9E9E9E),
                BlendMode.srcIn,
              ),
              child: Image.asset(iconPath, width: 24, height: 24, fit: BoxFit.contain),
            ),
            const SizedBox(height: 8),
            Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isActive ? const Color(0xFFD93BFF) : const Color(0xFF9E9E9E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loadingNumber) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6EEF4),
      floatingActionButton: _buildCenterCallButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildCustomBottomNav(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                SizedBox(
  width: MediaQuery.of(context).size.width * 0.52,
  child: FittedBox(
    alignment: Alignment.centerLeft,
    fit: BoxFit.scaleDown,
    child: Text(
      'Hey, ${_userName ?? 'User'} 👋',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Colors.black87,
      ),
    ),
  ),
),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))
                          .then((_) => _loadUserData());
                    },
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFEEDDDD),
                      backgroundImage: _photoUrl.isNotEmpty
                          ? (_photoUrl.startsWith('data:image')
                              ? MemoryImage(base64Decode(_photoUrl.split(',').last)) as ImageProvider
                              : NetworkImage(_photoUrl))
                          : null,
                      child: _photoUrl.isEmpty ? const Icon(Icons.person, size: 22, color: Colors.black54) : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Live Translation Ready
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
                ),
                child: Row(
                  children: [
                    Container(width: 10, height: 10,
                        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Live Translation Ready', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        Text('System is ready _ Choose a contact to start to call',
                            style: TextStyle(fontSize: 11, color: Colors.black45)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              _startCallCard(context),
              const SizedBox(height: 20),
              _buildRecentCallsSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Painter ────────────────────────────────────────────────────────────────────
class BottomNavPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = const Color(0xFFFFF6F7)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    const double cornerRadius = 20.0; // ← chota corner (Figma jaisa)
    const double notchRadius = 38.0;
    final double cx = size.width * 0.50;
    final double notchLeft = cx - notchRadius - 6;
    final double notchRight = cx + notchRadius + 6;

    final path = Path();

    // top-left corner — kam rounded
    path.moveTo(cornerRadius, 0);

    // top edge left → notch
    path.lineTo(notchLeft, 0);

    // smooth dip into notch
    path.cubicTo(
      notchLeft + 12, 0,
      cx - notchRadius, 4,
      cx - notchRadius + 2, notchRadius * 0.32,
    );

    // arc across bottom of notch
    path.arcToPoint(
      Offset(cx + notchRadius - 2, notchRadius * 0.32),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );

    // smooth rise out of notch
    path.cubicTo(
      cx + notchRadius, 4,
      notchRight - 12, 0,
      notchRight, 0,
    );

    // top edge right → top-right corner
    path.lineTo(size.width - cornerRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, cornerRadius);

    // right side
    path.lineTo(size.width, size.height - cornerRadius);
    path.quadraticBezierTo(size.width, size.height, size.width - cornerRadius, size.height);

    // bottom edge
    path.lineTo(cornerRadius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);

    // left side
    path.lineTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);

    path.close();

    canvas.drawShadow(path, Colors.black26, 8, false);
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}