import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'contacts_screen.dart';
import 'forget_password_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'sign_in_screen.dart';
import 'chat_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final int _selectedIndex = 3;

  // ── User data ─────────────────────────────────────────────────────────────
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _appNumber = '';
  String _preferredLanguage = 'English';
  String _timeZone = 'GMT+5';
  String _photoUrl = '';
  bool _loading = true;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  String get _fullName => '${_firstName.trim()} ${_lastName.trim()}'.trim();

  // ── Firebase ──────────────────────────────────────────────────────────────

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data() ?? {};

      final fullName = (data['name'] ?? '').toString().trim();
      final parts = fullName.split(' ');

      setState(() {
        _firstName =
            data['firstName'] ?? (parts.isNotEmpty ? parts.first : '');
        _lastName = data['lastName'] ??
            (parts.length > 1 ? parts.sublist(1).join(' ') : '');
        _email = FirebaseAuth.instance.currentUser?.email ?? '';
_appNumber = (data['number'] ?? '').toString();_preferredLanguage =
    (data['preferredLanguageLabel'] ?? 'English').toString();        _timeZone = data['timeZone'] ?? 'GMT+5';
_photoUrl = (data['photoUrl'] ?? '').toString();        _loading = false;
      });
    } catch (e) {
      debugPrint('Profile load failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateFirestore(Map<String, dynamic> fields) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        ...fields,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore update failed: $e');
    }
  }

  // ── Image Picker ──────────────────────────────────────────────────────────

  Future<void> _pickAndUploadImage() async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Choose Photo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined,
                color: Color(0xFFD93BFF)),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined,
                color: Color(0xFFD93BFF)),
            title: const Text('Take a Photo'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
          if (_photoUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: Colors.redAccent),
              title: const Text('Remove Photo',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () => Navigator.of(ctx).pop(null),
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );

  if (!mounted) return;

  // Remove photo
  if (source == null && _photoUrl.isNotEmpty) {
    await _updateFirestore({'photoUrl': ''});
    if (mounted) setState(() => _photoUrl = '');
    return;
  }

  if (source == null) return;

  try {
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 50,  // compress karo Firestore size ke liye
      maxWidth: 300,     // small size
      maxHeight: 300,
    );
    if (picked == null) return;

    // Base64 mein convert karo
    final bytes = await picked.readAsBytes();
    final base64String = base64Encode(bytes);
    final dataUrl = 'data:image/jpeg;base64,$base64String';

    // Firestore mein save karo (Storage nahi)
    await _updateFirestore({'photoUrl': dataUrl});

    if (mounted) {
      setState(() => _photoUrl = dataUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated!')),
      );
    }
  } catch (e) {
    debugPrint('Image save failed: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save image. Try again.')),
      );
    }
  }
}

  // ── Edit Profile bottom sheet ─────────────────────────────────────────────

  void _showEditProfileDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Edit Profile',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: Color(0xFFD93BFF)),
              title: const Text('Change Profile Photo'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickAndUploadImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined,
                  color: Color(0xFFD93BFF)),
              title: const Text('Edit Name & Time Zone'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showEditNameDialog();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
void _showLanguagePicker() {
  final languages = [
    {'code': 'en', 'label': 'English'},
    {'code': 'ur', 'label': 'Urdu'},
    {'code': 'ar', 'label': 'Arabic'},
    {'code': 'fr', 'label': 'French'},
    {'code': 'es', 'label': 'Spanish'},
    {'code': 'it', 'label': 'Italian'},
    {'code': 'de', 'label': 'German'},
    {'code': 'ja', 'label': 'Japanese'},
    {'code': 'tr', 'label': 'Turkish'},
   {'code': 'zh-Hans', 'label': 'Chinese'},
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.72,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Language',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: languages.length,
                itemBuilder: (context, index) {
                  final lang = languages[index];
                  final label = lang['label']!;
                  final code = lang['code']!;

                  return ListTile(
                    leading: Icon(
                      Icons.language,
                      color: _preferredLanguage == label
                          ? const Color(0xFFD93BFF)
                          : Colors.black45,
                    ),
                    title: Text(label),
                    trailing: _preferredLanguage == label
                        ? const Icon(Icons.check, color: Color(0xFFD93BFF))
                        : null,
                    onTap: () async {
                      Navigator.of(ctx).pop();

                      await _updateFirestore({
                        'preferredLanguageCode': code,
                        'preferredLanguageLabel': label,
                      });

                      if (!mounted) return;

                      setState(() {
                        _preferredLanguage = label;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Language set to $label')),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}
  // ── Edit Name dialog ──────────────────────────────────────────────────────

  void _showEditNameDialog() {
    final nameCtrl =
        TextEditingController(text: '$_firstName $_lastName'.trim());
    final tzCtrl = TextEditingController(text: _timeZone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tzCtrl,
              decoration: const InputDecoration(
                labelText: 'Time Zone (e.g. GMT+5)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final fullName = nameCtrl.text.trim();
              final tz = tzCtrl.text.trim();
              if (fullName.isEmpty) return;

              final parts = fullName.split(' ');
              final fn = parts.first;
              final ln =
                  parts.length > 1 ? parts.sublist(1).join(' ') : '';

              await _updateFirestore({
                'name': fullName,
                'firstName': fn,
                'lastName': ln,
                'timeZone': tz,
              });

              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();

              if (mounted) {
                setState(() {
                  _firstName = fn;
                  _lastName = ln;
                  _timeZone = tz;
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Delete Account ────────────────────────────────────────────────────────

  void _showDeleteAccountDialog() {
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently delete your account and all data. '
              'This cannot be undone.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Enter your password to confirm',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              try {
                final user = FirebaseAuth.instance.currentUser!;
                final cred = EmailAuthProvider.credential(
                  email: user.email!,
                  password: passCtrl.text,
                );
                await user.reauthenticateWithCredential(cred);

                final uid = user.uid;

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .delete();

              

                await user.delete();

                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                if (!mounted) return;

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const SignInScreen()),
                  (route) => false,
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Nav ────────────────────────────────────────────────────────────

  Widget _buildFab() => GestureDetector(
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

  Widget _bottomNavigationBar(BuildContext context) => Container(
        height: 72,
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        child: CustomPaint(
          painter: ProfileNavPainter(),
          child: Container(
padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _navItem(
                    context: context,
                    index: 0,
                    iconPath: 'assets/images/homeicon.png',
                    label: 'Home'),
                _navItem(
                    context: context,
                    index: 1,
                    iconPath: 'assets/images/contact_icon.png',
                    label: 'Contacts'),
                const SizedBox(width: 40),
                _navItem(context: context, index: 2, iconPath: 'assets/images/chat_icon.png', label: 'Chats'),
_navItem(context: context, index: 3, iconPath: 'assets/images/settingicon.png', label: 'Settings'),
              ],
            ),
          ),
        ),
      );

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
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const HomeScreen()));
          return;
        }
        if (index == 1) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const ContactsScreen()));
          return;
        }
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
                active
                    ? const Color(0xFFD93BFF)
                    : const Color(0xFF9E9E9E),
                BlendMode.srcIn,
              ),
              child: Image.asset(iconPath,
                  width: 24, height: 24, fit: BoxFit.contain),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active
                    ? const Color(0xFFD93BFF)
                    : const Color(0xFF9E9E9E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── UI Helpers ────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.black45,
            letterSpacing: 1.1,
          ),
        ),
      );

  Widget _card({required List<Widget> children}) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.80),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
          ],
        ),
        child: Column(children: children),
      );

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    Color labelColor = Colors.black87,
    Color iconColor = Colors.black54,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: labelColor,
                  ),
                ),
              ),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 12, color: Colors.black45),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 18, color: Colors.black38),
            ],
          ),
        ),
      );

  Widget _divider() =>
      const Divider(height: 1, indent: 54, color: Color(0xFFEEDDEE));

  Widget _defaultAvatar() => Container(
        color: const Color(0xFFEEDDDD),
        child: const Icon(Icons.person, size: 52, color: Colors.black45),
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6EEF4),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _bottomNavigationBar(context),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Page title
                    const Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Avatar + name + email + Edit Profile
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickAndUploadImage,
                            child: Container(
                              width: 104,
                              height: 104,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF7B2FBE),
                                    Color(0xFFE91E8C),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              padding: const EdgeInsets.all(3),
                              child: ClipOval(
                                child: _photoUrl.isNotEmpty
    ? (_photoUrl.startsWith('data:image')
        ? Image.memory(
            base64Decode(_photoUrl.split(',').last),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _defaultAvatar(),
          )
        : Image.network(
            _photoUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _defaultAvatar(),
          ))
    : _defaultAvatar(),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          Text(
                            _fullName.isEmpty ? 'User' : _fullName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            _email,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black45),
                          ),

                          const SizedBox(height: 10),

                          GestureDetector(
                            onTap: _showEditProfileDialog,
                            child: const Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFD93BFF),
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFFD93BFF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Personal Information
                    _sectionLabel('Personal Information'),
                    _card(children: [
                      _infoTile(
                        icon: Icons.person_outline,
                        label: 'Name',
                        value: _fullName.isEmpty ? '---' : _fullName,
                        onTap: _showEditNameDialog,
                      ),
                      _divider(),
                      _infoTile(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: _email.isEmpty ? '---' : _email,
                      ),
                      _divider(),
                      _infoTile(
                        icon: Icons.phone_outlined,
                        label: 'Phone Number',
                        value:
                            _appNumber.isEmpty ? '---' : _appNumber,
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // Preferences
                    _card(children: [
                      _infoTile(
                        icon: Icons.language,
                        label: 'Preferred Language',
                        value: _preferredLanguage,
                         onTap: _showLanguagePicker,
                      ),
                      _divider(),
                      _infoTile(
                        icon: Icons.access_time_outlined,
                        label: 'Time Zone',
                        value: _timeZone,
                        onTap: _showEditNameDialog,
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // Account Actions
                    _sectionLabel('Account Actions'),
                    _card(children: [
                      _infoTile(
                        icon: Icons.lock_outline,
                        label: 'Change Password',
                        value: '',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgetPasswordScreen(),
                          ),
                        ),
                      ),
                      _divider(),
                      _infoTile(
                        icon: Icons.delete_outline,
                        label: 'Delete Account',
                        value: '',
                        labelColor: Colors.redAccent,
                        iconColor: Colors.redAccent,
                        onTap: _showDeleteAccountDialog,
                      ),
                    ]),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Painter ────────────────────────────────────────────────────────────────────
class ProfileNavPainter extends CustomPainter {
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