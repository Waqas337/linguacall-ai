import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_screen.dart';
import 'sign_in_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _linesFade;
  late Animation<double> _circleScale;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _ring1;
  late Animation<double> _ring2;
  late Animation<double> _iconsFade;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _linesFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.0, 0.25, curve: Curves.easeIn)));

    _circleScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.15, 0.5, curve: Curves.elasticOut)));

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.35, 0.65, curve: Curves.elasticOut)));

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.35, 0.6, curve: Curves.easeIn)));

    _ring1 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.55, 0.8, curve: Curves.easeOut)));

    _ring2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.65, 0.9, curve: Curves.easeOut)));

    _iconsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.75, 1.0, curve: Curves.easeIn)));

    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 3200), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final onboardingSeen = prefs.getBool('onboarding_seen') ?? false;
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;

    if (user != null) {
      Navigator.pushReplacement(context, _fadeRoute(const HomeScreen()));
    } else if (!onboardingSeen) {
      Navigator.pushReplacement(context, _fadeRoute(const OnboardingScreen()));
    } else {
      Navigator.pushReplacement(context, _fadeRoute(const SignInScreen()));
    }
  }

  Route _fadeRoute(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Stack(
            children: [
              

              // ── Outer ring 2 ──
              Center(
                child: Opacity(
                  opacity: _ring2.value,
                  child: Container(
                    width: size.width * 0.85 * _ring2.value,
                    height: size.width * 0.85 * _ring2.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFB3C1).withOpacity(0.3),
                    ),
                  ),
                ),
              ),

              // ── Outer ring 1 ──
              Center(
                child: Opacity(
                  opacity: _ring1.value,
                  child: Container(
                    width: size.width * 0.70 * _ring1.value,
                    height: size.width * 0.70 * _ring1.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF6B8A).withOpacity(0.25),
                    ),
                  ),
                ),
              ),

              // ── Pink circle ──
              Center(
                child: Transform.scale(
                  scale: _circleScale.value,
                  child: Container(
                    width: size.width * 0.52,
                    height: size.width * 0.52,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFF2D6B),
                    ),
                  ),
                ),
              ),

              // ── Logo ──
              Center(
                child: Opacity(
                  opacity: _logoFade.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: SizedBox(
                      width: size.width * 0.44,
                      height: size.width * 0.44,
                      child: Image.asset(
                        'assets/images/new_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.translate_rounded,
                                  color: Colors.white, size: 48),
                              const SizedBox(height: 6),
                              const Text('Bhasha',
                                  style: TextStyle(color: Colors.white,
                                      fontSize: 22, fontWeight: FontWeight.w800)),
                              Text('CONNECT EVERY HEART',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                      fontSize: 8, letterSpacing: 1.5)),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // ── Floating icons ──
              Opacity(
                opacity: _iconsFade.value,
                child: Stack(
                  children: [
                    Positioned(top: size.height * 0.12, right: size.width * 0.08,
                        child: _floatIcon(Icons.chat_bubble_rounded, const Color(0xFFDA3AE8), 28)),
                    Positioned(top: size.height * 0.18, left: size.width * 0.06,
                        child: _floatIcon(Icons.translate_rounded, const Color(0xFF7B2FBE), 24)),
                    Positioned(top: size.height * 0.38, right: size.width * 0.05,
                        child: _floatIcon(Icons.mic_rounded, const Color(0xFFDA3AE8), 22)),
                    Positioned(top: size.height * 0.45, left: size.width * 0.04,
                        child: _floatIcon(Icons.videocam_rounded, const Color(0xFF7B2FBE), 26)),
                    Positioned(bottom: size.height * 0.18, right: size.width * 0.08,
                        child: _floatIcon(Icons.call_rounded, const Color(0xFFDA3AE8), 24)),
                    Positioned(bottom: size.height * 0.22, left: size.width * 0.07,
                        child: _floatIcon(Icons.language_rounded, const Color(0xFF7B2FBE), 22)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _floatIcon(IconData icon, Color color, double size) {
    return Container(
      width: size + 18,
      height: size + 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12)],
      ),
      child: Icon(icon, color: color, size: size * 0.65),
    );
  }
}