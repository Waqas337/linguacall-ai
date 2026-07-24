import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'call_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'home_screen.dart';
import 'chat_list_screen.dart';
import 'chat_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
int _selectedIndex = 1;
  String _searchText = '';
  String _selectedFilter = 'all'; // all, favorites

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _contactsRef {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('contacts');
  }
Widget _bottomNavigationBar(BuildContext context) {
  return Container(
    height: 72,
    margin: const EdgeInsets.fromLTRB(18, 0, 18, 16),
    child: CustomPaint(
      painter: ContactsNavPainter(),
      child: Container(
padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _navItem(
              context: context,
              index: 0,
              iconPath: 'assets/images/homeicon.png',
              label: 'Home',
            ),
            _navItem(
              context: context,
              index: 1,
              iconPath: 'assets/images/contact_icon.png',
              label: 'Contacts',
            ),
            const SizedBox(width: 40),
            _navItem(context: context, index: 2, iconPath: 'assets/images/chat_icon.png', label: 'Chats'),
_navItem(context: context, index: 3, iconPath: 'assets/images/settingicon.png', label: 'Settings'),
          ],
        ),
      ),
    ),
  );
}

Widget _navItem({
  required BuildContext context,
  required int index,
  required String iconPath,
  required String label,
}) {
  final bool active = _selectedIndex == index;

  return GestureDetector(
    onTap: () {
      if (index == 0) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
        return;
      }
      if (index == 1) return;
if (index == 2) {
  Navigator.push(context,
      MaterialPageRoute(builder: (_) => const ChatListScreen()));
  return;
}
if (index == 3) {
  Navigator.push(context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()));
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
  active ? const Color(0xFFD93BFF) : const Color(0xFF9E9E9E),
  BlendMode.srcIn,
),
            child: Image.asset(iconPath, width: 24, height: 24,
                fit: BoxFit.contain),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? const Color(0xFFD93BFF) : const Color(0xFF9E9E9E),
            ),
          ),
        ],
      ),
    ),
  );
}
Widget _buildFab() {
  return GestureDetector(
    onTap: () {},
    child: Container(
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
    ),
  );
}
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAddContactDialog() async {
  final nameController = TextEditingController();
  final numberController = TextEditingController();

  await showDialog(
    context: context,
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        backgroundColor: const Color(0xFFFFF6F7),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF7B2FBE), Color(0xFFE91E8C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.person_add_rounded,
                    color: Colors.white, size: 26),
              ),

              const SizedBox(height: 14),

              const Text(
                'Add Contact',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Save a new contact to your list',
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),

              const SizedBox(height: 20),

              // Name field
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFDA3AE8),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    hintText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline,
                        color: Color(0xFFDA3AE8)),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Number field
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFDA3AE8),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: numberController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  buildCounter: (_, {required currentLength,
                      required isFocused, maxLength}) => null,
                  decoration: const InputDecoration(
                    hintText: '6-digit Number',
                    prefixIcon: Icon(Icons.dialpad_rounded,
                        color: Color(0xFFDA3AE8)),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(
                            color: Color(0xFFDA3AE8), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFFDA3AE8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                          final savedName = nameController.text.trim();
                          final number = numberController.text
                              .replaceAll(RegExp(r'\s+'), '')
                              .trim();

                          if (savedName.isEmpty || number.isEmpty) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Name and number required')),
                            );
                            return;
                          }

                          final success = await _saveContact(
                            savedName: savedName,
                            number: number,
                          );

                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? 'Contact saved!'
                                  : 'Failed to save contact'),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding:
                              const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
Future<void> _saveRecentCall({
  required String otherUid,
  required String otherNumber,
  required String direction,
  required String callType,
}) async {
  if (_uid == null) return;

  final cleanNumber = otherNumber.replaceAll(RegExp(r'\s+'), '').trim();

  if (cleanNumber.isEmpty) return;

  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('recentCalls')
        .add({
      'otherUid': otherUid,
      'otherNumber': cleanNumber,
      'direction': direction,
      'callType': callType,
      'createdAt': FieldValue.serverTimestamp(),
    });

    debugPrint('Recent call saved from contacts: $cleanNumber');
  } catch (e) {
    debugPrint('Failed to save recent call from contacts: $e');
  }
}

  Future<bool> _saveContact({
  required String savedName,
  required String number,
}) async {
  if (_uid == null) return false;

  try {
    await _contactsRef.add({
      'savedName': savedName.trim(),
      'number': number.replaceAll(RegExp(r'\s+'), '').trim(),
      'favorite': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('Contact saved: $savedName - $number');
    return true;
  } catch (e) {
    debugPrint('Failed to save contact: $e');
    return false;
  }
}

  Future<void> _toggleFavorite(String docId, bool currentValue) async {
    try {
      await _contactsRef.doc(docId).update({
        'favorite': !currentValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Favorite update failed: $e');
    }
  }

  Future<void> _deleteContact(String docId) async {
    try {
      await _contactsRef.doc(docId).delete();
    } catch (e) {
      debugPrint('Delete contact failed: $e');
    }
  }

  Future<void> _editContact({
    required String docId,
    required String currentName,
    required String currentNumber,
  }) async {
    final nameController = TextEditingController(text: currentName);
    final numberController = TextEditingController(text: currentNumber);

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Contact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: numberController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Number',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
             onPressed: () async {
  final updatedName = nameController.text.trim();
  final updatedNumber =
      numberController.text.replaceAll(RegExp(r'\s+'), '').trim();

  if (updatedName.isEmpty || updatedNumber.isEmpty) {
    return;
  }

  await _contactsRef.doc(docId).update({
    'savedName': updatedName,
    'number': updatedNumber,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  if (!ctx.mounted) return;
  Navigator.of(ctx).pop();
},
              child: const Text('Update'),
            ),
          ],
        );
      },
    );

  }

  Future<void> _startCallWithNumber(String number) async {
    final cleanNumber = number.replaceAll(RegExp(r'\s+'), '').trim();

    if (cleanNumber.isEmpty) return;

    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      final numberDoc = await FirebaseFirestore.instance
          .collection('numbers')
          .doc(cleanNumber)
          .get(const GetOptions(source: Source.serverAndCache));

      if (!numberDoc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
        return;
      }

      final calleeUid = numberDoc.data()?['uid']?.toString() ?? '';

      if (calleeUid.isEmpty || currentUid.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('UID missing')),
        );
        return;
      }
await _saveRecentCall(
  otherUid: calleeUid,
  otherNumber: cleanNumber,
  direction: 'outgoing',
  callType: 'video',
);
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            isCaller: true,
            calleeUid: calleeUid,
            callerUid: currentUid,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Call start failed from contacts: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start call')),
      );
    }
  }

  bool _matchesSearch({
    required String name,
    required String number,
  }) {
    if (_searchText.isEmpty) return true;

    final q = _searchText.toLowerCase();
    return name.toLowerCase().contains(q) || number.contains(q);
  }

  Widget _buildFilterChip({
    required String keyValue,
    required String label,
  }) {
    final isActive = _selectedFilter == keyValue;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = keyValue;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withOpacity(0.65),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive ? const Color(0xFFDA3AE8) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isActive ? const Color(0xFFDA3AE8) : Colors.black54,
          ),
        ),
      ),
    );
  }
Widget _buildAlphabetSection(String letter, List<Widget> tiles) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, top: 12, bottom: 6),
        child: Text(
          letter,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.black45,
            letterSpacing: 1.1,
          ),
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: tiles),
      ),
    ],
  );
}

  Widget _buildContactTile({
    required String docId,
    required String name,
    required String number,
    required bool favorite,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: Color(0xFFEEDDDD),
            child: Icon(Icons.person, color: Colors.black54),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
  name,
  style: const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  ),
),
const SizedBox(height: 2),
Text(
  number,
  style: const TextStyle(
    fontSize: 12,
    color: Colors.black45,
  ),
),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _toggleFavorite(docId, favorite),
            icon: Icon(
              favorite ? Icons.favorite : Icons.favorite_border,
              color: favorite ? Colors.red : Colors.black38,
            ),
          ),
          IconButton(
            onPressed: () => _startCallWithNumber(number),
            icon: const Icon(Icons.call, color: Colors.black87),
          ),
         
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                await _editContact(
                  docId: docId,
                  currentName: name,
                  currentNumber: number,
                );
              } else if (value == 'delete') {
                await _deleteContact(docId);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    return Scaffold(
      
      backgroundColor: const Color(0xFFF6EEF4),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  children: [
                    // Header Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Contacts',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: _showAddContactDialog,
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  width: 2,
                                  color: const Color(0xFFDA3AE8),
                                ),
                              ),
                              child: const Icon(Icons.add, size: 28),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Search
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          width: 2,
                          color: const Color(0xFFDA3AE8),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchText = value.trim();
                          });
                        },
                        decoration: const InputDecoration(
                          icon: Icon(Icons.search, color: Colors.black45),
                          hintText: 'Search contacts',
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Filters
                    Row(
                      children: [
                        _buildFilterChip(keyValue: 'all', label: 'All'),
                        const SizedBox(width: 10),
                        _buildFilterChip(
                          keyValue: 'favorites',
                          label: 'Favorites',
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // List Card
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _contactsRef
                            .orderBy('createdAt', descending: true)
                            .limit(50)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 30),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Text(
                                'Failed to load contacts',
                                style: TextStyle(color: Colors.red),
                              ),
                            );
                          }

                          final docs = snapshot.data?.docs ?? [];

                          final filteredDocs = docs.where((doc) {
                            final data = doc.data();
                            final name =
                                (data['savedName'] ?? '').toString().trim();
                            final number =
                                (data['number'] ?? '').toString().trim();
                            final favorite = data['favorite'] == true;

                            if (!_matchesSearch(name: name, number: number)) {
                              return false;
                            }

                            if (_selectedFilter == 'favorites' && !favorite) {
                              return false;
                            }

                            return true;
                          }).toList();

                          if (filteredDocs.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 30),
                              child: Center(
                                child: Text(
                                  'No contacts found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            );
                          }

                          // Group by first letter
final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped = {};
for (final doc in filteredDocs) {
  final name = (doc.data()['savedName'] ?? '').toString().trim();
  final letter = name.isNotEmpty
      ? name[0].toUpperCase()
      : '#';
  grouped.putIfAbsent(letter, () => []).add(doc);
}

// Sort letters A-Z
final sortedLetters = grouped.keys.toList()..sort();

return Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: sortedLetters.map((letter) {
    final docs = grouped[letter]!;
    final tiles = <Widget>[];

    for (int i = 0; i < docs.length; i++) {
      final data = docs[i].data();
      final savedName = (data['savedName'] ?? '').toString();
      final number = (data['number'] ?? '').toString();
      final favorite = data['favorite'] == true;

      tiles.add(_buildContactTile(
        docId: docs[i].id,
        name: savedName,
        number: number,
        favorite: favorite,
      ));

      if (i < docs.length - 1) {
        tiles.add(const Divider(height: 1, indent: 54));
      }
    }

    return _buildAlphabetSection(letter, tiles);
  }).toList(),
);
                        },
                      ),
                    
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
floatingActionButton: _buildFab(),
floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
bottomNavigationBar: _bottomNavigationBar(context),    );
  }
}
class ContactsNavPainter extends CustomPainter {
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
    path.quadraticBezierTo(size.width, size.height, size.width - cornerRadius, size.height);
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