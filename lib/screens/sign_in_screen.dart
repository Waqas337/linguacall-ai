import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'forget_password_screen.dart';
import 'sign_up_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'home_screen.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _loading = false;
bool _showPassword = false;
  Future<void> _signIn() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email aur password dono likho.')),
      );
      return;
    }

    try {
      setState(() => _loading = true);

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Agar main.dart me authStateChanges wala StreamBuilder laga hua hai
      // toh yahan navigation zaroori nahi.
      // Lekin UX smooth rakhne ke liye pushReplacement kar dete hain:
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Login failed';
      if (e.code == 'user-not-found') {
        msg = 'User nahi mila. Pehle sign up karo.';
      } else if (e.code == 'wrong-password') {
        msg = 'Galat password.';
      } else if (e.code == 'invalid-email') {
        msg = 'Email format sahi nahi hai.';
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
Future<void> _signInWithGoogle() async {
  try {
    setState(() => _loading = true);

    final GoogleSignInAccount? googleUser =
        await GoogleSignIn(scopes: ['email']).signIn();

    if (googleUser == null) {
      setState(() => _loading = false);
      return;
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);

    final user = userCredential.user;
    if (user == null) return;

    final uid = user.uid;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (!doc.exists) {
      final random = Random();
      String number = '';
      for (int i = 0; i < 20; i++) {
        final n = (100000 + random.nextInt(900000)).toString();
        final existing = await FirebaseFirestore.instance
            .collection('numbers')
            .doc(n)
            .get();
        if (!existing.exists) {
          await FirebaseFirestore.instance
              .collection('numbers')
              .doc(n)
              .set({'uid': uid});
          number = n;
          break;
        }
      }
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': user.displayName ?? 'User',
        'email': user.email ?? '',
        'number': number,
        'preferredLanguageCode': 'en',
        'preferredLanguageLabel': 'English',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  } catch (e) {
    debugPrint('Google Sign-In error: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In failed: $e')),
      );
    }
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Center(
        child: SizedBox(
          width: size.width > 500 ? 428 : size.width * 0.95,
          height: 926,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 80),

                // Top bar style
                Row(
                  children: [
                    const SizedBox(width: 16),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                    const Spacer(),
                    const Text(
                      'Sign in',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(flex: 2),
                  ],
                ),

                const SizedBox(height: 24),

                Text(
                  "Let’s continue the conversation",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.6),
                    fontFamily: 'Poppins',
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 40),

                // Email + Password fields
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Email',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'example@gmail.com',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Password',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
  controller: _passwordCtrl,
  obscureText: !_showPassword,
  decoration: InputDecoration(
    hintText: '********',
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
    ),
    suffixIcon: IconButton(
      icon: Icon(
        _showPassword ? Icons.visibility : Icons.visibility_off,
      ),
      onPressed: () {
        setState(() {
          _showPassword = !_showPassword;
        });
      },
    ),
  ),
),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () { Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ForgetPasswordScreen()),
      );
                            
                            // TODO: Forgot password flow (Firebase sendPasswordResetEmail)
                          },
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: Color(0xFFB327F2),
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Sign in button with gradient
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.zero,
                        elevation: 4,
                        backgroundColor: Colors.transparent,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFB327F2), Color(0xFFF52560)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: _loading
                              ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Sign in',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'or',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
                ),

                const SizedBox(height: 16),

                // Google button (UI only for now)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child:OutlinedButton(
  style: OutlinedButton.styleFrom(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  onPressed: _loading ? null : _signInWithGoogle,
  child: const Text(
    'Continue with Google',
    style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
  ),
),
                  ),
                ),

                const SizedBox(height: 24),

                // Sign up link
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignUpScreen()),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don’t have an account? ",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                      const Text(
                        "Sign Up",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Color(0xFFB327F2),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
