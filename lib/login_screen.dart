import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onNavigateToWelcome;
  final VoidCallback onNavigateToSignup;
  final Function(Map<String, dynamic>, [String?]) onLogin;

  const LoginScreen({
    Key? key,
    required this.onNavigateToWelcome,
    required this.onNavigateToSignup,
    required this.onLogin,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _showPassword = false;
  String? _generalError;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _floatController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();

    // Check Firebase initialization
    _checkFirebaseInit();

    // Animation setup
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _floatAnimation = Tween<double>(
      begin: 0,
      end: -3,
    ).animate(CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeInOut,
    ));

    _slideController.forward();
    _floatController.repeat(reverse: true);
  }

  Future<void> _checkFirebaseInit() async {
    try {
      await Firebase.initializeApp();
      print('✅ Firebase initialized successfully');
    } catch (e) {
      print('❌ Firebase initialization error: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _slideController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  // FIXED: Enhanced login with proper data handling
  Future<void> _handleLogin() async {
    print('🔐 === LOGIN ATTEMPT STARTED ===');

    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      print('📧 Attempting login with email: $email');

      // ✅ STEP 1: Firebase Authentication
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('Firebase authentication failed - no user returned');
      }

      print('✅ Firebase auth successful!');
      print('👤 Firebase User UID: ${firebaseUser.uid}');
      print('👤 Firebase User Email: ${firebaseUser.email}');

      // ✅ STEP 2: Get authentication token
      String? idToken = await firebaseUser.getIdToken();

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Failed to get authentication token');
      }

      print('🎫 Token obtained successfully');

      // ✅ STEP 3: Build user data with guaranteed UID and email
      Map<String, dynamic> userData = {
        'uid': firebaseUser.uid,  // ✅ GUARANTEED from Firebase
        'email': firebaseUser.email ?? email,  // ✅ GUARANTEED
        'name': firebaseUser.displayName ?? email.split('@')[0],
        'emailVerified': firebaseUser.emailVerified,
        'isAnonymous': firebaseUser.isAnonymous,
        'provider': 'email',
        'photoURL': firebaseUser.photoURL,
        'profileCompleted': false,  // Default value
      };

      // ✅ STEP 4: Try to enhance with Firestore data (optional)
      try {
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          print('📊 Found Firestore document, merging data...');

          Map<String, dynamic> firestoreData =
          Map<String, dynamic>.from(userDoc.data() as Map<String, dynamic>);

          // ✅ MERGE: Add Firestore data but preserve essential Firebase fields
          userData.addAll(firestoreData);

          // ✅ ENSURE: Critical fields are never overwritten
          userData['uid'] = firebaseUser.uid;
          userData['email'] = firebaseUser.email ?? email;

          // Update last login
          await _firestore.collection('users').doc(firebaseUser.uid).update({
            'lastLoginAt': FieldValue.serverTimestamp(),
          });

          print('✅ User data merged from Firestore');
        } else {
          print('ℹ️ No Firestore document found, using Firebase Auth data only');
        }
      } catch (firestoreError) {
        print('⚠️ Firestore error (continuing anyway): $firestoreError');
        // Continue with Firebase Auth data only
      }

      // ✅ STEP 5: Final validation before callback
      print('🔍 Final validation before callback:');
      print('🔍 userData[\'uid\']: ${userData['uid']}');
      print('🔍 userData[\'email\']: ${userData['email']}');
      print('🔍 token length: ${idToken.length}');

      // ✅ DOUBLE-CHECK: Ensure we have what we need
      if (userData['uid'] == null || userData['uid'].toString().isEmpty) {
        throw Exception('Critical error: UID is still null after processing');
      }

      if (userData['email'] == null || userData['email'].toString().isEmpty) {
        throw Exception('Critical error: Email is still null after processing');
      }

      // ✅ STEP 6: Call the main app login function
      print('🚀 Calling widget.onLogin...');
      widget.onLogin(userData, idToken);
      print('✅ Login process completed successfully');

    } on FirebaseAuthException catch (e) {
      print('🔥 FirebaseAuthException: ${e.code} - ${e.message}');

      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email. Please sign up first.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid email or password. Please check your credentials.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed attempts. Please try again later.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your connection.';
          break;
        default:
          errorMessage = 'Login failed: ${e.message ?? 'Unknown error'}';
      }

      setState(() {
        _generalError = errorMessage;
      });

    } catch (e) {
      print('💥 Unexpected error: $e');
      setState(() {
        _generalError = 'Login failed: ${e.toString()}';
      });

    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Enhanced forgot password functionality
  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      setState(() {
        _generalError = 'Please enter your email address first.';
      });
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      setState(() {
        _generalError = 'Please enter a valid email address.';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _generalError = null;
      });

      await _auth.sendPasswordResetEmail(email: email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Password reset email sent to $email\nPlease check your inbox and spam folder.',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _generalError = 'No account found with this email address.\nPlease check your email or sign up first.';
            break;
          case 'invalid-email':
            _generalError = 'Please enter a valid email address.';
            break;
          case 'too-many-requests':
            _generalError = 'Too many requests. Please wait before trying again.';
            break;
          default:
            _generalError = 'Failed to send reset email: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _generalError = 'Failed to send reset email. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
          ),
        ),
        child: Stack(
          children: [
            // ✅ FIXED: Removed problematic background pattern
            // Simple gradient background instead of network image
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF667eea).withOpacity(0.9),
                    const Color(0xFF764ba2).withOpacity(0.9),
                  ],
                ),
              ),
            ),

            SafeArea(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 420,
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildHeader(),
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _slideController,
                            child: _buildFormSection(),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _slideController,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.2),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _slideController,
          curve: Curves.easeOut,
        )),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 40, 0, 30),
          child: Column(
            children: [
              // Navigation Header
              Row(
                children: [
                  GestureDetector(
                    onTap: widget.onNavigateToWelcome,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 2),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 64),
                ],
              ),
              const SizedBox(height: 24),

              // Login Intro
              Column(
                children: [
                  // ✅ FIXED: Simple animated icon instead of network image
                  AnimatedBuilder(
                    animation: _floatAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _floatAnimation.value),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 32,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.login,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sign In to Continue',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(0, 2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Access your Lost & Found account',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w400,
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

  Widget _buildFormSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 60,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // General Error Message
            if (_generalError != null) _buildGeneralError(),

            // Email Input
            _buildEmailInput(),
            const SizedBox(height: 20),

            // Password Input
            _buildPasswordInput(),
            const SizedBox(height: 16),

            // Forgot Password Link
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _handleForgotPassword,
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: Color(0xFF667eea),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Login Button
            _buildLoginButton(),

            const SizedBox(height: 24),

            // Sign Up Link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Don\'t have an account? ',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                GestureDetector(
                  onTap: widget.onNavigateToSignup,
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(
                      color: Color(0xFF667eea),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFe53e3e).withOpacity(0.1),
        border: Border.all(
          color: const Color(0xFFe53e3e).withOpacity(0.2),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _generalError!,
        style: const TextStyle(
          color: Color(0xFFc53030),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildEmailInput() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        enableSuggestions: false,
        onChanged: (value) {
          if (_generalError != null) {
            setState(() => _generalError = null);
          }
        },
        decoration: InputDecoration(
          hintText: 'Email Address',
          hintStyle: const TextStyle(color: Color(0xFFa0aec0)),
          prefixIcon: const Icon(Icons.mail_outline, color: Color(0xFF718096)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFe2e8f0), width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFe2e8f0), width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
          ),
          contentPadding: const EdgeInsets.fromLTRB(48, 16, 20, 16),
        ),
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF2d3748),
        ),
        validator: (value) {
          if (value?.isEmpty ?? true) {
            return 'Please enter your email address';
          }
          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) {
            return 'Please enter a valid email address';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPasswordInput() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _passwordController,
        obscureText: !_showPassword,
        autocorrect: false,
        enableSuggestions: false,
        onChanged: (value) {
          if (_generalError != null) {
            setState(() => _generalError = null);
          }
        },
        decoration: InputDecoration(
          hintText: 'Password',
          hintStyle: const TextStyle(color: Color(0xFFa0aec0)),
          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF718096)),
          suffixIcon: Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF718096),
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFe2e8f0), width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFe2e8f0), width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
          ),
          contentPadding: const EdgeInsets.fromLTRB(48, 16, 52, 16),
        ),
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF2d3748),
        ),
        validator: (value) {
          if (value?.isEmpty ?? true) {
            return 'Please enter your password';
          }
          if (value!.length < 6) {
            return 'Password must be at least 6 characters';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _handleLogin,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: _isLoading
                ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              ),
            )
                : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Sign In',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 18, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}