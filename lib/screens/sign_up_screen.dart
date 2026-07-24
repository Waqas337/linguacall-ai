import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../constants/supported_languages.dart';
import 'home_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  String selectedLanguageCode = 'en';
  String selectedLanguageLabel = 'English';

  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _loading = false;
  bool _agreeTerms = false;

  Future<String> _generateUniqueAppNumber() async {
    final random = Random();
    final usersRef = FirebaseFirestore.instance.collection('users');

    for (int i = 0; i < 30; i++) {
      final number = (100000 + random.nextInt(900000)).toString();

      final existing = await usersRef
          .where('number', isEqualTo: number)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        debugPrint('Generated unique app number: $number');
        return number;
      }
    }

    throw Exception('Unique app number generate nahi ho saka. Dobara try karo.');
  }

  Future<void> _saveUserProfile({
    required String uid,
    required String username,
    required String email,
    required String appNumber,
  }) async {
    final data = {
      'uid': uid,
      'name': username,
      'email': email,
      'number': appNumber,
      'preferredLanguageCode': selectedLanguageCode,
      'preferredLanguageLabel': selectedLanguageLabel,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    debugPrint('Saving user profile: $data');

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));

    final verifyDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    debugPrint('Verified saved profile: ${verifyDoc.data()}');
    debugPrint('User profile saved successfully');
  }

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();

    if (_loading) return;

    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terms & Conditions se agree karo.')),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final username = _usernameCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text.trim();

    UserCredential? cred;

    try {
      setState(() => _loading = true);

      debugPrint('Creating auth user...');

      cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;

      if (user == null) {
        throw Exception('User create hua lekin null return hua.');
      }

      await user.updateDisplayName(username);
      await user.reload();

      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) {
        throw Exception('Auth user refresh ke baad null ho gaya.');
      }

      final uid = refreshedUser.uid;

      debugPrint('Auth user created: $uid');

      final generatedNumber = await _generateUniqueAppNumber();

      await _saveUserProfile(
        uid: uid,
        username: username,
        email: email,
        appNumber: generatedNumber,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account created successfully. Your app number is $generatedNumber',
          ),
        ),
      );

      // small delay taake snackbar/render/save settle ho jaye
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: ${e.code} | ${e.message}');

      String msg = 'Sign up failed';

      if (e.code == 'email-already-in-use') {
        msg = 'Ye email pehle se registered hai.';
      } else if (e.code == 'weak-password') {
        msg = 'Password weak hai, thora strong rakho.';
      } else if (e.code == 'invalid-email') {
        msg = 'Email format sahi nahi hai.';
      } else if (e.code == 'network-request-failed') {
        msg = 'Internet issue hai. Network check karo.';
      } else if (e.code == 'operation-not-allowed') {
        msg = 'Email/password sign up Firebase me enable nahi hai.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      debugPrint('Sign up error: $e');

      // rollback only if firestore/profile save fail after auth creation
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await currentUser.delete();
          debugPrint('Rolled back auth user because profile save failed');
        }
      } catch (deleteError) {
        debugPrint('Rollback delete failed: $deleteError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
      ),
    );
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
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  Row(
                    children: [
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_back, size: 20),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Create Account',
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
                    'Start your journey with real-time translation',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.6),
                      fontFamily: 'Poppins',
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Username',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _usernameCtrl,
                          decoration: _inputDecoration('Alexa Roy'),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return 'Username required hai';
                            }
                            if (text.length < 3) {
                              return 'Username kam az kam 3 letters ka ho';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Email',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration('example@gmail.com'),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return 'Email required hai';
                            }
                            if (!_isValidEmail(text)) {
                              return 'Email format sahi nahi hai';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Preferred Language',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedLanguageCode,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          items: supportedLanguages.map((lang) {
                            return DropdownMenuItem<String>(
                              value: lang.code,
                              child: Text(lang.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;

                            final selected = supportedLanguages.firstWhere(
                              (e) => e.code == value,
                            );

                            setState(() {
                              selectedLanguageCode = selected.code;
                              selectedLanguageLabel = selected.name;
                            });
                          },
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
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: !_showPassword,
                          decoration: InputDecoration(
                            hintText: '********',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showPassword = !_showPassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return 'Password required hai';
                            }
                            if (text.length < 6) {
                              return 'Password kam az kam 6 characters ka ho';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Confirm Password',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _confirmPasswordCtrl,
                          obscureText: !_showConfirmPassword,
                          decoration: InputDecoration(
                            hintText: '********',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showConfirmPassword =
                                      !_showConfirmPassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            final confirm = value?.trim() ?? '';
                            if (confirm.isEmpty) {
                              return 'Confirm password required hai';
                            }
                            if (confirm != _passwordCtrl.text.trim()) {
                              return 'Password match nahi kar raha';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _agreeTerms,
                              onChanged: (v) {
                                setState(() => _agreeTerms = v ?? false);
                              },
                            ),
                            const SizedBox(width: 4),
                            const Expanded(
                              child: Wrap(
                                children: [
                                  Text(
                                    'Agree with ',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'Terms & Conditions',
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
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _signUp,
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
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Sign up',
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
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _loading ? null : _signInWithGoogle,
                        child: const Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Colors.black.withOpacity(0.6),
                          ),
                        ),
                        const Text(
                          'Log In',
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
      ),
    );
  }
}