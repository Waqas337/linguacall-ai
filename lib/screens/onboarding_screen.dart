import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sign_in_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<_PageData> _pages = const [
    _PageData(
      imagePath: 'assets/images/person1.png',
      title: 'Talk naturally in your language',
      subtitle: 'Speak freely without choosing words or worrying about accents.',
      gradientColors: [Color(0xFF9B59F5), Color(0xFFE8A0FF), Color(0xFFFFFFFF)],
    ),
    _PageData(
      imagePath: 'assets/images/person2.png',
      title: 'Live video call translation',
      subtitle: 'Live subtitles and translated audio keep the conversation flowing without pauses.',
      gradientColors: [Color(0xFF5B8EF5), Color(0xFFB8D4FF), Color(0xFFFFFFFF)],
    ),
    _PageData(
      imagePath: 'assets/images/person3.png',
      title: 'Connect across borders',
      subtitle: 'Distance and language can\'t stop communication anymore. Meet, learn, and collaborate with anyone.',
      gradientColors: [Color(0xFF9B59F5), Color(0xFFE8A0FF), Color(0xFFFFFFFF)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _fadeController.reset();
      _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic);
      _fadeController.forward();
    } else {
      _goToSignIn();
    }
  }

  Future<void> _goToSignIn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const SignInScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Pages ──
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) {
              setState(() => _currentPage = i);
              _fadeController.reset();
              _fadeController.forward();
            },
            itemCount: _pages.length,
            itemBuilder: (context, index) =>
                _buildPage(_pages[index], index),
          ),

          // ── Bottom fixed area ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) {
                        final active = i == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFF7B2FBE)
                                : const Color(0xFFD0B3E8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),

                    // Full width gradient button
                    GestureDetector(
                      onTap: _next,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7B2FBE), Color(0xFFDA3AE8),
                                Color(0xFFFF2D6B)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF2D6B).withOpacity(0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Text(
                          _currentPage == _pages.length - 1
                              ? 'Get Started'
                              : 'Continue',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_PageData data, int index) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // ── Top image area with gradient background ──
          Expanded(
            flex: 55,
            child: Stack(
              children: [
                // Gradient background (top only)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: data.gradientColors,
                      ),
                    ),
                  ),
                ),

                // Person image
                Positioned.fill(
                  child: Image.asset(
                    data.imagePath,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(
                          Icons.person_rounded,
                          size: 160,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      );
                    },
                  ),
                ),

                // Screen 1 — phone mockup
                if (index == 0)
                  Positioned(
                    right: 12,
                    top: 40,
                    child: _PhoneMockup(),
                  ),

                // Screen 2 — chat bubbles
                if (index == 1)
                  Positioned(
                    bottom: 16,
                    left: 12,
                    right: 12,
                    child: _VideoChatBubbles(),
                  ),

                // Screen 3 — circle + chat icons
                if (index == 2)
                  Positioned.fill(
                    child: _ConnectCircleOverlay(),
                  ),
              ],
            ),
          ),

          // ── White text area ──
          Expanded(
            flex: 45,
            child: Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF0D0D0D),
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    data.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF6B6B6B),
                      fontSize: 15,
                      height: 1.6,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// Screen 1 — Phone mockup
// ══════════════════════════════════════════
class _PhoneMockup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 10))
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Notch
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Language bar
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _pill('🇯🇵', 'Jp'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.swap_horiz, color: Colors.white38, size: 14),
              ),
              _pill('🇬🇧', 'Eng'),
            ],
          ),
          const SizedBox(height: 12),

          // Left bubble
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF7B2FBE), Color(0xFFDA3AE8)]),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
                bottomLeft: Radius.circular(3),
              ),
            ),
            child: const Text('こんにちは',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2, top: 3),
            child: Text('Listening to...',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.3), fontSize: 8)),
          ),
          const SizedBox(height: 8),

          // Right bubble
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(3),
                ),
              ),
              child: const Text('Hello',
                  style: TextStyle(
                      color: Color(0xFF0D0D1A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String flag, String name) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 9)),
            const SizedBox(width: 3),
            Text(name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

// ══════════════════════════════════════════
// Screen 2 — Video chat bubbles
// ══════════════════════════════════════════
class _VideoChatBubbles extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top right bubble
        Align(
          alignment: Alignment.centerRight,
          child: _bubble(
            'Let\'s make this call fun!\n楽しい電話にしましょう！',
            const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 8),
        // Bottom left bubble
        Align(
          alignment: Alignment.centerLeft,
          child: _bubble(
            'I\'ve got a story for you!\n話したいことがあるんだ！',
            const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 4),
        // Bottom right bubble
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Hey!\nやぁ！',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bubble(String text, Color color) => Container(
        constraints: const BoxConstraints(maxWidth: 190),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.4)),
      );
}

// ══════════════════════════════════════════
// Screen 3 — Connect circle + chat icons
// ══════════════════════════════════════════
class _ConnectCircleOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cx = size.width / 2;
    final cy = size.height * 0.22;
    final r = size.width * 0.38;

    return Stack(
      children: [
        // Circle outline
        Positioned(
          left: cx - r,
          top: cy - r,
          child: Container(
            width: r * 2,
            height: r * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFDA3AE8).withOpacity(0.5),
                width: 2,
              ),
            ),
          ),
        ),

        // Chat icon bubbles around the circle
        _iconAt(cx + r * 0.7, cy - r * 0.7,
            Icons.chat_bubble_rounded, const Color(0xFF7B2FBE)),
        _iconAt(cx - r * 0.85, cy - r * 0.5,
            Icons.chat_bubble_rounded, const Color(0xFF3AE8DA)),
        _iconAt(cx + r * 0.9, cy + r * 0.2,
            Icons.chat_bubble_rounded, const Color(0xFFDA3AE8)),
        _iconAt(cx - r * 0.75, cy + r * 0.6,
            Icons.chat_bubble_rounded, const Color(0xFF7B2FBE)),
        _iconAt(cx + r * 0.3, cy - r * 1.0,
            Icons.chat_bubble_rounded, const Color(0xFFDA3AE8)),
      ],
    );
  }

  Widget _iconAt(double left, double top, IconData icon, Color color) {
    return Positioned(
      left: left - 20,
      top: top - 20,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.4), blurRadius: 10)
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ══════════════════════════════════════════
// Data model
// ══════════════════════════════════════════
class _PageData {
  final String imagePath;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  const _PageData({
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
  });
}