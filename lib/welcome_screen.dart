import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToSignup;
  final VoidCallback onNavigateToLogin;
  final Function(Map<String, dynamic>, [String?]) onLogin;

  const WelcomeScreen({
    Key? key,
    required this.onNavigateToSignup,
    required this.onNavigateToLogin,
    required this.onLogin,
  }) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _showPassword = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Firebase instances - SAME AS LoginScreen
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late AnimationController _floatController;
  late AnimationController _slideController;
  late Animation<double> _floatAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Check Firebase initialization
    _checkFirebaseInit();

    // Float animation for logo
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _floatAnimation = Tween<double>(
      begin: 0,
      end: -5,
    ).animate(CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeInOut,
    ));
    _floatController.repeat(reverse: true);

    // Slide up animation for cards
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
    _slideController.forward();
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
    _floatController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Email validation
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  // Password validation
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  // FIXED: Use same Firebase logic as LoginScreen
  void _handleSocialLogin(String provider) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // For now, show message that social login needs to be implemented
      setState(() {
        _errorMessage = 'Social login with $provider will be implemented soon. Please use email login for now.';
      });

      // TODO: Implement actual social login
      // Example for Google: await _auth.signInWithCredential(GoogleAuthProvider.credential(...));

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to login with $provider. Please try again.';
      });
      print('Social login error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // FIXED: Use EXACT same logic as your working LoginScreen
  Future<void> _handleEmailLogin() async {
    print('🔐 === WELCOME SCREEN LOGIN ATTEMPT STARTED ===');

    // Clear previous error
    setState(() {
      _errorMessage = null;
    });

    // Validate form
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      print('📧 Attempting login with email: $email');

      // ✅ STEP 1: Firebase Authentication (SAME AS LoginScreen)
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

      // ✅ STEP 2: Get authentication token (SAME AS LoginScreen)
      String? idToken = await firebaseUser.getIdToken();

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Failed to get authentication token');
      }

      print('🎫 Token obtained successfully');

      // ✅ STEP 3: Build user data (SAME AS LoginScreen)
      Map<String, dynamic> userData = {
        'uid': firebaseUser.uid,
        'email': firebaseUser.email ?? email,
        'name': firebaseUser.displayName ?? email.split('@')[0],
        'emailVerified': firebaseUser.emailVerified,
        'isAnonymous': firebaseUser.isAnonymous,
        'provider': 'email',
        'photoURL': firebaseUser.photoURL,
        'profileCompleted': false,
      };

      // ✅ STEP 4: Try to enhance with Firestore data (SAME AS LoginScreen)
      try {
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          print('📊 Found Firestore document, merging data...');

          Map<String, dynamic> firestoreData =
          Map<String, dynamic>.from(userDoc.data() as Map<String, dynamic>);

          userData.addAll(firestoreData);

          // Ensure critical fields are never overwritten
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
      }

      // ✅ STEP 5: Final validation (SAME AS LoginScreen)
      print('🔍 Final validation before callback:');
      print('🔍 userData[\'uid\']: ${userData['uid']}');
      print('🔍 userData[\'email\']: ${userData['email']}');
      print('🔍 token length: ${idToken.length}');

      if (userData['uid'] == null || userData['uid'].toString().isEmpty) {
        throw Exception('Critical error: UID is still null after processing');
      }

      if (userData['email'] == null || userData['email'].toString().isEmpty) {
        throw Exception('Critical error: Email is still null after processing');
      }

      // ✅ STEP 6: Call the main app login function (SAME AS LoginScreen)
      print('🚀 Calling widget.onLogin...');
      widget.onLogin(userData, idToken);
      print('✅ Welcome Screen login process completed successfully');

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
        _errorMessage = errorMessage;
      });

    } catch (e) {
      print('💥 Unexpected error: $e');
      setState(() {
        _errorMessage = 'Login failed: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _extractNameFromEmail(String email) {
    return email.split('@')[0].replaceAll(RegExp(r'[^a-zA-Z0-9]'), ' ').trim();
  }

  bool get _isLoginButtonEnabled =>
      _emailController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty &&
          !_isLoading;

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
            // Simple gradient background (same as LoginScreen)
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
            // Main content
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Header Section
                        _buildHeader(),
                        const SizedBox(height: 30),

                        // Welcome Message
                        _buildWelcomeMessage(),
                        const SizedBox(height: 32),

                        // Login Section
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _slideController,
                            child: _buildLoginSection(),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // New User Section
                        SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.5),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _slideController,
                            curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
                          )),
                          child: FadeTransition(
                            opacity: CurvedAnimation(
                              parent: _slideController,
                              curve: const Interval(0.3, 1.0),
                            ),
                            child: _buildNewUserSection(),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Loading overlay
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          // Animated Logo
          AnimatedBuilder(
            animation: _floatAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _floatAnimation.value),
                child: GestureDetector(
                  onTap: () {
                    // Add scale animation on tap
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
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
                      Icons.search,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          // App Name
          const Text(
            'Lost & Found',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 2),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Tagline
          Text(
            'Find what\'s lost, return what\'s found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    return Column(
      children: [
        const Text(
          'Welcome!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.5,
            shadows: [
              Shadow(
                color: Colors.black26,
                offset: Offset(0, 2),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'If you\'re new here, please create an account to get started.\nExisting users can sign in below.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.9),
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginSection() {
    return Form(
      key: _formKey,
      child: Container(
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
        child: Column(
          children: [
            // Login Title
            const Text(
              'Sign In to Your Account',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1a202c),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Error Message
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Email Input
            _buildEmailInput(),
            const SizedBox(height: 20),

            // Password Input
            _buildPasswordInput(),
            const SizedBox(height: 32),

            // Login Button
            _buildLoginButton(),
            const SizedBox(height: 24),

            // Divider
            _buildDivider(),
            const SizedBox(height: 20),

            // Social Login Buttons
            _buildSocialLoginButtons(),
          ],
        ),
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
        validator: _validateEmail,
        onChanged: (_) => setState(() {
          _errorMessage = null; // Clear error when user types
        }),
        decoration: InputDecoration(
          hintText: 'Email address',
          hintStyle: const TextStyle(color: Color(0xFFa0aec0)),
          prefixIcon: const Icon(
            Icons.mail_outline,
            color: Color(0xFF718096),
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          contentPadding: const EdgeInsets.fromLTRB(48, 16, 20, 16),
        ),
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF2d3748),
        ),
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
        validator: _validatePassword,
        onChanged: (_) => setState(() {
          _errorMessage = null; // Clear error when user types
        }),
        decoration: InputDecoration(
          hintText: 'Password',
          hintStyle: const TextStyle(color: Color(0xFFa0aec0)),
          prefixIcon: const Icon(
            Icons.lock_outline,
            color: Color(0xFF718096),
          ),
          suffixIcon: Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF718096),
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
              style: IconButton.styleFrom(
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          contentPadding: const EdgeInsets.fromLTRB(48, 16, 52, 16),
        ),
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF2d3748),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isLoginButtonEnabled
              ? [const Color(0xFF667eea), const Color(0xFF764ba2)]
              : [Colors.grey.shade400, Colors.grey.shade500],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: _isLoginButtonEnabled
            ? [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoginButtonEnabled ? _handleEmailLogin : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ❌ REMOVED: Button loader - only show text and icon
                Text(
                  'Sign In',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: Color(0xFFe2e8f0), thickness: 1),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: Colors.white.withOpacity(0.95),
          child: const Text(
            'or continue with',
            style: TextStyle(
              color: Color(0xFF718096),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: Color(0xFFe2e8f0), thickness: 1),
        ),
      ],
    );
  }

  Widget _buildSocialLoginButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildSocialButton(
            'Google',
            Colors.white,
            const Color(0xFF4a5568),
            _buildGoogleIcon(),
                () => _handleSocialLogin('Google'),
            const Color(0xFFea4335),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSocialButton(
            'Facebook',
            Colors.white,
            const Color(0xFF4a5568),
            const Icon(Icons.facebook, color: Color(0xFF1877f2), size: 18),
                () => _handleSocialLogin('Facebook'),
            const Color(0xFF1877f2),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton(
      String label,
      Color backgroundColor,
      Color textColor,
      Widget icon,
      VoidCallback onPressed,
      Color hoverColor,
      ) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFe2e8f0), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(
            'https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Google_%22G%22_Logo.svg/512px-Google_%22G%22_Logo.svg.png',
          ),
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildNewUserSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        children: [
          // Title and description
          const Text(
            'New to Lost & Found?',
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
          ),
          const SizedBox(height: 12),
          Text(
            'Join thousands of users helping each other find lost items in their community.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.9),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Create Account Button
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onNavigateToSignup,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Create Your Account',
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
          ),
          const SizedBox(height: 20),

          // Features Preview
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFeatureItem('📍', 'Location-Based'),
              const SizedBox(width: 24),
              _buildFeatureItem('🔐', 'Secure & Private'),
              const SizedBox(width: 24),
              _buildFeatureItem('🤝', 'Community Driven'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String icon, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
