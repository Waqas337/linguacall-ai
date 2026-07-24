import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'chat_screen.dart';
import 'home_screen.dart';
import 'contacts_screen.dart';
import 'settings_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final String? _myUid = FirebaseAuth.instance.currentUser?.uid;
  final int _selectedIndex = 2; // Chats active

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $ampm';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _startNewChat() async {
    if (_myUid == null) return;

    final contactsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_myUid)
        .collection('contacts')
        .orderBy('savedName')
        .get();

    if (!mounted) return;

    if (contactsSnap.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contacts found. Add a contact first.')),
      );
      return;
    }

    final rootNavigator = Navigator.of(context);
    final rootMessenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('New Chat',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: contactsSnap.docs.length,
                itemBuilder: (context, index) {
                  final data = contactsSnap.docs[index].data();
                  final name = data['savedName'] ?? '';
                  final number = data['number'] ?? '';

                  return ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF2D6B), Color(0xFFDA3AE8)],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    title: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(number,
                        style: const TextStyle(color: Colors.black45)),
                    onTap: () async {
                      Navigator.pop(ctx);

                      String realUid = (data['uid'] ?? '').toString().trim();

                      if (realUid.isEmpty && number.toString().trim().isNotEmpty) {
                        try {
                          final numDoc = await FirebaseFirestore.instance
                              .collection('numbers')
                              .doc(number.toString().trim())
                              .get();
                          realUid = (numDoc.data()?['uid'] ?? '').toString().trim();
                        } catch (e) {
                          debugPrint('UID fetch error: $e');
                        }
                      }

                      if (realUid.isEmpty) {
                        rootMessenger.showSnackBar(
                          const SnackBar(
                              content: Text('User not found. Make sure they are registered.')),
                        );
                        return;
                      }

                      if (realUid == _myUid) {
                        rootMessenger.showSnackBar(
                          const SnackBar(content: Text('Cannot chat with yourself')),
                        );
                        return;
                      }

                      rootNavigator.push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            otherUid: realUid,
                            otherName: name.toString(),
                            otherNumber: number.toString(),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Bottom Nav ─────────────────────────────────────────────────────────────

  Widget _buildCenterCallButton() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: SvgPicture.asset(
          'assets/images/Floating_button.svg',
          fit: BoxFit.cover,
        ),
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
              painter: ChatListNavPainter(),
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
        if (index == 0) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
          return;
        }
        if (index == 1) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ContactsScreen()));
          return;
        }
        if (index == 2) return;
        if (index == 3) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
          return;
        }
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
            Text(
              label,
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6EEF4),
      floatingActionButton: _buildCenterCallButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildCustomBottomNav(),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Text(
                    'Chats',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _startNewChat,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF2D6B), Color(0xFFDA3AE8)],
                        ),
                      ),
                      child: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // Chat list
            Expanded(
              child: _myUid == null
                  ? const Center(child: Text('Not logged in'))
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('chats')
                          .where('participants', arrayContains: _myUid)
                          .orderBy('lastMessageTime', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data?.docs ?? [];

                        if (docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFFF2D6B).withOpacity(0.1),
                                  ),
                                  child: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    color: Color(0xFFFF2D6B),
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No chats yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap + to start a new conversation',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final data = docs[index].data();
                            final participants = List<String>.from(data['participants'] ?? []);
                            final otherUid = participants.firstWhere((p) => p != _myUid, orElse: () => '');
                            final lastMsg = (data['lastMessage'] ?? '').toString();
                            final lastTime = data['lastMessageTime'] as Timestamp?;
                            final lastSender = (data['lastSenderId'] ?? '').toString();
                            final isMe = lastSender == _myUid;

                            return Dismissible(
                              key: Key(docs[index].id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
                              ),
                              confirmDismiss: (direction) async {
                                return await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    title: const Text('Delete Chat'),
                                    content: const Text('Are you sure you want to delete this chat?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              onDismissed: (direction) async {
                                final messagesSnap = await FirebaseFirestore.instance
                                    .collection('chats')
                                    .doc(docs[index].id)
                                    .collection('messages')
                                    .get();
                                final batch = FirebaseFirestore.instance.batch();
                                for (final msg in messagesSnap.docs) {
                                  batch.delete(msg.reference);
                                }
                                batch.delete(FirebaseFirestore.instance
                                    .collection('chats')
                                    .doc(docs[index].id));
                                await batch.commit();
                              },
                              child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                future: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(otherUid)
                                    .get(),
                                builder: (context, userSnap) {
                                  String otherName = '';
                                  String otherNumber = '';

                                  if (userSnap.hasData && userSnap.data!.exists) {
                                    final ud = userSnap.data!.data()!;
                                    otherNumber = (ud['number'] ?? '').toString();
                                  }

                                  return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                    future: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(_myUid)
                                        .collection('contacts')
                                        .where('number', isEqualTo: otherNumber)
                                        .limit(1)
                                        .get(),
                                    builder: (context, contactSnap) {
                                      if (contactSnap.hasData &&
                                          contactSnap.data!.docs.isNotEmpty) {
                                        otherName = (contactSnap.data!.docs.first
                                                .data()['savedName'] ??
                                            '').toString();
                                      }

                                      if (otherName.isEmpty) {
                                        otherName = otherNumber.isEmpty ? 'Unknown' : otherNumber;
                                      }

                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ChatScreen(
                                                otherUid: otherUid,
                                                otherName: otherName,
                                                otherNumber: otherNumber,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.04),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 50,
                                                height: 50,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient: LinearGradient(
                                                    colors: [Color(0xFFFF2D6B), Color(0xFFDA3AE8)],
                                                  ),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    otherName.isNotEmpty
                                                        ? otherName[0].toUpperCase()
                                                        : '?',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 20,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      otherName,
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w700,
                                                        color: Color(0xFF1A1A2E),
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      isMe ? 'You: $lastMsg' : lastMsg,
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.grey.shade500),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    _formatTime(lastTime),
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey.shade400),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  StreamBuilder<QuerySnapshot>(
                                                    stream: FirebaseFirestore.instance
                                                        .collection('chats')
                                                        .doc(docs[index].id)
                                                        .collection('messages')
                                                        .where('senderId', isNotEqualTo: _myUid)
                                                        .where('read', isEqualTo: false)
                                                        .snapshots(),
                                                    builder: (context, unreadSnap) {
                                                      final count =
                                                          unreadSnap.data?.docs.length ?? 0;
                                                      if (count == 0) return const SizedBox.shrink();
                                                      return Container(
                                                        width: 20,
                                                        height: 20,
                                                        decoration: const BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          gradient: LinearGradient(
                                                            colors: [
                                                              Color(0xFFFF2D6B),
                                                              Color(0xFFDA3AE8)
                                                            ],
                                                          ),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            count > 9 ? '9+' : '$count',
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w700,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Painter ────────────────────────────────────────────────────────────────────
class ChatListNavPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = const Color(0xFFFFF6F7)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    const double cornerRadius = 20.0;
    const double notchRadius = 38.0;
    final double cx = size.width * 0.50;
    final double notchLeft = cx - notchRadius - 6;
    final double notchRight = cx + notchRadius + 6;

    final path = Path();
    path.moveTo(cornerRadius, 0);
    path.lineTo(notchLeft, 0);
    path.cubicTo(notchLeft + 12, 0, cx - notchRadius, 4,
        cx - notchRadius + 2, notchRadius * 0.32);
    path.arcToPoint(
      Offset(cx + notchRadius - 2, notchRadius * 0.32),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );
    path.cubicTo(cx + notchRadius, 4, notchRight - 12, 0, notchRight, 0);
    path.lineTo(size.width - cornerRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, cornerRadius);
    path.lineTo(size.width, size.height - cornerRadius);
    path.quadraticBezierTo(
        size.width, size.height, size.width - cornerRadius, size.height);
    path.lineTo(cornerRadius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);
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