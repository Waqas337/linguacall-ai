import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/supported_languages.dart';
import 'home_screen.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';
import 'chat_list_screen.dart';
import 'sign_in_screen.dart';
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
final int _selectedIndex = 3;

  // User data
  String _userName = '';
  String _userNumber = '';
  String _preferredLanguageCode = 'en';
  String _preferredLanguageLabel = 'English';
  bool _loadingUser = true;

  // Toggles
  bool _offlineMode = false;
  bool _captions = true;
  bool _voiceOver = false;
  bool _privacyMode = true;
  bool _vibrationEnabled = true; // global vibration toggle

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ── Vibration helper ──────────────────────────────────────────────────────

  void _vibrate() {
  if (!_vibrationEnabled) return;
  HapticFeedback.mediumImpact();
}

  // ── Firebase ──────────────────────────────────────────────────────────────

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loadingUser = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      if (data != null && mounted) {
       setState(() {
  _userName = data['name'] ?? 'User';
  _userNumber = data['number'] ?? '';
  _preferredLanguageCode = data['preferredLanguageCode'] ?? 'en';
  _preferredLanguageLabel = data['preferredLanguageLabel'] ?? 'English';
  _captions = data['captionsEnabled'] ?? true;
  _voiceOver = data['voiceOverEnabled'] ?? false;
  _loadingUser = false;
});
      }
    } catch (e) {
      debugPrint('Failed to load user: $e');
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  Future<void> _updateFirestore(Map<String, dynamic> fields) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({...fields, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('Firestore update failed: $e');
    }
  }

  Future<void> _logout() async {
    _vibrate();
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('Logout error: $e');
    }
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showLanguageDialog() {
    _vibrate();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Preferred Language'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: supportedLanguages.length,
            itemBuilder: (_, i) {
              final lang = supportedLanguages[i];
              final isSelected = lang.code == _preferredLanguageCode;
              return ListTile(
                title: Text(lang.name),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Color(0xFFD93BFF))
                    : null,
                onTap: () async {
                  _vibrate();
                  Navigator.of(ctx).pop();
                  setState(() {
                    _preferredLanguageCode = lang.code;
                    _preferredLanguageLabel = lang.name;
                  });
                  await _updateFirestore({
                    'preferredLanguageCode': lang.code,
                    'preferredLanguageLabel': lang.name,
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Language updated to ${lang.name}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAppearanceDialog() {
    _vibrate();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Appearance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.light_mode, color: Color(0xFFD93BFF)),
              title: const Text('Light Mode'),
              onTap: () {
                _vibrate();
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Light Mode selected'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode, color: Color(0xFFD93BFF)),
              title: const Text('Dark Mode'),
              onTap: () {
                _vibrate();
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Dark Mode selected (coming soon)'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showBlockedNumbersDialog() {
  _vibrate();
  final uid = FirebaseAuth.instance.currentUser?.uid;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Blocked Numbers'),
      content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('blockedNumbers')
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No blocked numbers.'),
            );
          }
          return SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final number = docs[i].data()['number'] ?? '';
                return ListTile(
                  title: Text(number),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle,
                        color: Colors.redAccent),
                    onPressed: () {
                      _vibrate();
                      docs[i].reference.delete();
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: () async {
            final numberCtrl = TextEditingController();
            await showDialog(
              context: ctx,
              builder: (ctx2) => AlertDialog(
                title: const Text('Block Number'),
                content: TextField(
                  controller: numberCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    hintText: '6-digit number',
                    border: OutlineInputBorder(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx2).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final number = numberCtrl.text.trim();
                      if (number.isEmpty || number.length != 6) return;
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('blockedNumbers')
                          .doc(number)
                          .set({'number': number});
                      if (!ctx2.mounted) return;
                      Navigator.of(ctx2).pop();
                    },
                    child: const Text('Block'),
                  ),
                ],
              ),
            );
          },
          child: const Text(
            'Add',
            style: TextStyle(color: Color(0xFFD93BFF)),
          ),
        ),
      ],
    ),
  );
}

  void _showLoginActivityDialog() {
    _vibrate();
    final user = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Login Activity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow('Email', user?.email ?? '---'),
            const SizedBox(height: 10),
            _infoRow('Status', 'Active'),
            const SizedBox(height: 10),
            _infoRow('Date', '${now.day}/${now.month}/${now.year}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAccountSettingsDialog() {
    _vibrate();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Account Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.email_outlined,
                  color: Color(0xFFD93BFF)),
              title: Text(
                  FirebaseAuth.instance.currentUser?.email ?? '---'),
              subtitle: const Text('Email'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.numbers, color: Color(0xFFD93BFF)),
              title:
                  Text(_userNumber.isEmpty ? '---' : _userNumber),
              subtitle: const Text('Your Number'),
            ),
            ListTile(
              leading: const Icon(Icons.language,
                  color: Color(0xFFD93BFF)),
              title: Text(_preferredLanguageLabel),
              subtitle: const Text('Caption Language'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    _vibrate();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📧  kashafzainab337@gmail.com'),
            
            SizedBox(height: 10),
            Text('📞  Mon–Fri, 9AM–6PM'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ── UI Helpers ────────────────────────────────────────────────────────────

  Widget _infoRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: Colors.black54, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      );

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
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4))
          ],
        ),
        child: Column(children: children),
      );

  Widget _divider() =>
      const Divider(height: 1, color: Color(0xFFE8D8E8));

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color iconColor = Colors.black54,
    Color titleColor = Colors.black87,
  }) =>
      InkWell(
        onTap: onTap != null
            ? () {
                _vibrate();
                onTap();
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: titleColor)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black45)),
                    ],
                  ],
                ),
              ),
              trailing ??
                  const Icon(Icons.chevron_right,
                      size: 20, color: Colors.black38),
            ],
          ),
        ),
      );

  // ── Bottom Nav ────────────────────────────────────────────────────────────

  Widget _buildFab() => GestureDetector(
        onTap: _vibrate,
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
          painter: SettingsNavPainter(),
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
        _vibrate();
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
if (index == 3) return; // Settings active hai
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
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? const Color(0xFFD93BFF)
                      : const Color(0xFF9E9E9E),
                )),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6EEF4),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _bottomNavigationBar(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Profile Header Card ────────────────────────────────────
              // "Edit →" click pe ProfileScreen open hoga
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFEEDDDD),
                        border: Border.all(
                            color: const Color(0xFFDA3AE8), width: 2),
                      ),
                      child: const Icon(Icons.person,
                          size: 28, color: Colors.black54),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _loadingUser
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userName.isEmpty ? 'User' : _userName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  '${_userNumber.isEmpty ? '---' : _userNumber}  •  $_preferredLanguageLabel',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black45),
                                ),
                              ],
                            ),
                    ),
                    // Edit → opens ProfileScreen
                    TextButton(
                      onPressed: () {
                        _vibrate();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProfileScreen()),
                        ).then((_) {
                          // Reload user data when returning from profile
                          _loadUserData();
                        });
                      },
                      child: const Text(
                        'Edit →',
                        style: TextStyle(
                          color: Color(0xFFD93BFF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ── PREFERENCES ───────────────────────────────────────────
              _sectionLabel('Preferences'),
              _card(children: [
                // Appearance — Light / Dark option dialog
                _settingsTile(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  subtitle: 'Light / Dark Mode',
                  onTap: _showAppearanceDialog,
                ),
                _divider(),
                _settingsTile(
                  icon: Icons.language,
                  title: 'Preferred Language',
                  subtitle: _preferredLanguageLabel,
                  onTap: _showLanguageDialog,
                ),
                _divider(),
                _settingsTile(
                  icon: Icons.wifi_off_outlined,
                  title: 'Offline Mode',
                  trailing: Switch(
                    value: _offlineMode,
                    activeColor: const Color(0xFFD93BFF),
                    onChanged: (val) {
                      _vibrate();
                      setState(() => _offlineMode = val);
                    },
                  ),
                ),
              ]),

              const SizedBox(height: 20),

              // ── AUDIO & ACCESSIBILITY ─────────────────────────────────
              _sectionLabel('Audio & Accessibility'),
              _card(children: [
                // Sound & Vibrations — vibration toggle
                _settingsTile(
                  icon: Icons.vibration,
                  title: 'Vibration',
                  subtitle: 'Vibrate on every tap in the app',
                  trailing: Switch(
                    value: _vibrationEnabled,
                    activeColor: const Color(0xFFD93BFF),
                    onChanged: (val) {
                      setState(() => _vibrationEnabled = val);
                      if (val) HapticFeedback.mediumImpact();
                    },
                  ),
                ),
                _divider(),
               _settingsTile(
  icon: Icons.closed_caption_outlined,
  title: 'Captions',
  trailing: Switch(
    value: _captions,
    activeColor: const Color(0xFFD93BFF),
    onChanged: (val) {
      _vibrate();
      setState(() => _captions = val);
      _updateFirestore({'captionsEnabled': val});
    },
  ),
),
                _divider(),
                _settingsTile(
  icon: Icons.record_voice_over_outlined,
  title: 'Voice Over',
  trailing: Switch(
    value: _voiceOver,
    activeColor: const Color(0xFFD93BFF),
    onChanged: (val) {
      _vibrate();
      setState(() => _voiceOver = val);
      _updateFirestore({'voiceOverEnabled': val});
    },
  ),
),
              ]),

              const SizedBox(height: 20),

              // ── PRIVACY & SECURITY ────────────────────────────────────
              _sectionLabel('Privacy & Security'),
              _card(children: [
                _settingsTile(
                  icon: Icons.lock_outline,
                  title: 'Privacy Mode',
                  subtitle: 'Audio is processed locally and not stored.',
                  trailing: Switch(
                    value: _privacyMode,
                    activeColor: const Color(0xFFD93BFF),
                    onChanged: (val) {
                      _vibrate();
                      setState(() => _privacyMode = val);
                    },
                  ),
                ),
                _divider(),
                _settingsTile(
                  icon: Icons.block_outlined,
                  title: 'Blocked Numbers',
                  onTap: _showBlockedNumbersDialog,
                ),
                _divider(),
                _settingsTile(
                  icon: Icons.history,
                  title: 'Login Activity',
                  onTap: _showLoginActivityDialog,
                ),
              ]),

              const SizedBox(height: 20),

              // ── ACCOUNT ───────────────────────────────────────────────
              _sectionLabel('Account'),
              _card(children: [
                _settingsTile(
                  icon: Icons.manage_accounts_outlined,
                  title: 'Account Settings',
                  onTap: _showAccountSettingsDialog,
                ),
                _divider(),
                _settingsTile(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  onTap: _showHelpDialog,
                ),
                _divider(),
                _settingsTile(
                  icon: Icons.logout,
                  title: 'Logout',
                  titleColor: Colors.redAccent,
                  iconColor: Colors.redAccent,
                  trailing: const SizedBox.shrink(),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text(
                            'Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _logout(); // real Firebase signout
                            },
                            child: const Text(
                              'Logout',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
class SettingsNavPainter extends CustomPainter {
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