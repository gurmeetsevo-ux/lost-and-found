import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  final VoidCallback onNavigateToWelcome;
  final VoidCallback onNavigateToLogin;
  final Function(Map<String, dynamic>, [String?]) onSignup;

  const SignupScreen({
    Key? key,
    required this.onNavigateToWelcome,
    required this.onNavigateToLogin,
    required this.onSignup,
  }) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isAnonymous = false; // ✅ FIXED: Default to false for email/password users
  bool _isLoading = false;
  Map<String, String> _errors = {};
  String? _generalError;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late AnimationController _slideController;
  late AnimationController _floatController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();

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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _slideController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _handleInputChange(String field, String value) {
    setState(() {
      if (_errors.containsKey(field)) {
        _errors.remove(field);
      }
      _generalError = null;
    });
  }

  bool _validateForm() {
    Map<String, String> newErrors = {};

    if (_nameController.text.trim().isEmpty) {
      newErrors['name'] = 'Name is required';
    }

    if (_emailController.text.trim().isEmpty) {
      newErrors['email'] = 'Email is required';
    } else if (!_emailController.text.contains('@')) {
      newErrors['email'] = 'Please enter a valid email';
    }

    if (_passwordController.text.isEmpty) {
      newErrors['password'] = 'Password is required';
    } else if (_passwordController.text.length < 6) {
      newErrors['password'] = 'Password must be at least 6 characters';
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      newErrors['confirmPassword'] = 'Passwords do not match';
    }

    setState(() {
      _errors = newErrors;
    });

    return newErrors.isEmpty;
  }

  // ✅ FIXED: Firebase signup implementation
  Future<void> _handleSignup() async {
    print('🔐 === SIGNUP ATTEMPT STARTED ===');

    if (!_validateForm()) {
      print('❌ Form validation failed');
      return;
    }

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      print('📧 Signup Email: "$email"');
      print('👤 Signup Name: "$name"');
      print('🔒 Anonymous Mode: $_isAnonymous');

      // Create user with Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ Firebase user created: ${userCredential.user?.uid}');

      // Update Firebase Auth profile
      await userCredential.user!.updateDisplayName(name);
      print('✅ Display name updated');

      // ✅ FIXED: Prepare correct user data
      Map<String, dynamic> userData = {
        'uid': userCredential.user!.uid,
        'name': name,
        'email': email,
        'isAnonymous': _isAnonymous, // This will be false by default
        'provider': 'email',
        'photoURL': userCredential.user!.photoURL,
        'emailVerified': userCredential.user!.emailVerified,
        'profileCompleted': true,
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Save additional user data to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        ...userData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ User document created in Firestore');
      print('📊 User data: $userData');

      // Get ID token
      String? idToken = await userCredential.user!.getIdToken();
      print('🎫 ID Token received: ${idToken != null}');

      // Call the onSignup callback with user data and token
      if (userData.isNotEmpty && idToken != null) {
        print('🚀 Calling onSignup callback...');
        widget.onSignup(userData, idToken);
        print('✅ === SIGNUP COMPLETED SUCCESSFULLY ===');
      } else {
        throw Exception('Failed to get valid user data or token');
      }

    } on FirebaseAuthException catch (e) {
      print('🔥 FirebaseAuthException: ${e.code} - ${e.message}');

      setState(() {
        switch (e.code) {
          case 'email-already-in-use':
            _generalError = 'This email is already registered. Please use a different email or try logging in.';
            break;
          case 'invalid-email':
            _generalError = 'Please enter a valid email address.';
            break;
          case 'weak-password':
            _generalError = 'Password is too weak. Please choose a stronger password.';
            break;
          case 'operation-not-allowed':
            _generalError = 'Email signup is not enabled. Please contact support.';
            break;
          case 'network-request-failed':
            _generalError = 'Network error. Please check your connection and try again.';
            break;
          default:
            _generalError = 'Signup failed: ${e.message}';
        }
      });
    } catch (e) {
      print('💥 General Exception: $e');
      setState(() {
        _generalError = 'An unexpected error occurred. Please try again.';
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
            // Background pattern
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: const NetworkImage(
                        'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs><pattern id="grain" width="100" height="100" patternUnits="userSpaceOnUse"><circle cx="25" cy="25" r="1" fill="white" opacity="0.05"/><circle cx="75" cy="75" r="1" fill="white" opacity="0.05"/><circle cx="50" cy="10" r="0.5" fill="white" opacity="0.03"/></pattern></defs><rect width="100" height="100" fill="url(%23grain)"/></svg>'
                    ),
                    repeat: ImageRepeat.repeat,
                    opacity: 0.3,
                  ),
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
                      'Create Account',
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
              Column(
                children: [
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
                            Icons.search,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Join Lost & Found',
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
                    'Start helping your community today',
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
            if (_generalError != null) _buildGeneralError(),
            _buildInputGroup(
              controller: _nameController,
              placeholder: 'Full Name',
              icon: Icons.person_outline,
              fieldKey: 'name',
            ),
            const SizedBox(height: 20),
            _buildInputGroup(
              controller: _emailController,
              placeholder: 'Email Address',
              icon: Icons.mail_outline,
              fieldKey: 'email',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            _buildInputGroup(
              controller: _passwordController,
              placeholder: 'Password',
              icon: Icons.lock_outline,
              fieldKey: 'password',
              isPassword: true,
              showPassword: _showPassword,
              onTogglePassword: () => setState(() => _showPassword = !_showPassword),
            ),
            const SizedBox(height: 20),
            _buildInputGroup(
              controller: _confirmPasswordController,
              placeholder: 'Confirm Password',
              icon: Icons.lock_outline,
              fieldKey: 'confirmPassword',
              isPassword: true,
              showPassword: _showConfirmPassword,
              onTogglePassword: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
            ),
            const SizedBox(height: 20),
            _buildAnonymousToggle(),
            const SizedBox(height: 32),
            _buildSignupButton(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                GestureDetector(
                  onTap: widget.onNavigateToLogin,
                  child: const Text(
                    'Sign In',
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

  Widget _buildInputGroup({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    required String fieldKey,
    bool isPassword = false,
    bool showPassword = false,
    VoidCallback? onTogglePassword,
    TextInputType? keyboardType,
  }) {
    bool hasError = _errors.containsKey(fieldKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: hasError
                ? [
              BoxShadow(
                color: const Color(0xFFe53e3e).withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ]
                : [
              BoxShadow(
                color: const Color(0xFF667eea).withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword && !showPassword,
            keyboardType: keyboardType,
            onChanged: (value) => _handleInputChange(fieldKey, value),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: const TextStyle(color: Color(0xFFa0aec0)),
              prefixIcon: Icon(icon, color: const Color(0xFF718096)),
              suffixIcon: isPassword
                  ? Container(
                margin: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: Icon(
                    showPassword ? Icons.visibility_off : Icons.visibility,
                    color: const Color(0xFF718096),
                  ),
                  onPressed: onTogglePassword,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasError ? const Color(0xFFe53e3e) : const Color(0xFFe2e8f0),
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasError ? const Color(0xFFe53e3e) : const Color(0xFFe2e8f0),
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasError ? const Color(0xFFe53e3e) : const Color(0xFF667eea),
                  width: 2,
                ),
              ),
              contentPadding: EdgeInsets.fromLTRB(
                  48, 16, isPassword ? 52 : 20, 16
              ),
            ),
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF2d3748),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFe53e3e),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _errors[fieldKey]!,
                  style: const TextStyle(
                    color: Color(0xFFe53e3e),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAnonymousToggle() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF667eea).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF667eea).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🔒 Anonymous Mode',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2d3748),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hide your personal details by default for privacy',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF4a5568),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => setState(() => _isAnonymous = !_isAnonymous),
            child: Container(
              width: 52,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: _isAnonymous
                    ? const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                )
                    : null,
                color: _isAnonymous ? null : const Color(0xFFcbd5e0),
                boxShadow: _isAnonymous
                    ? [
                  BoxShadow(
                    color: const Color(0xFF667eea).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
                    : null,
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    left: _isAnonymous ? 24 : 2,
                    top: 2,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
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

  Widget _buildSignupButton() {
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
          onTap: _isLoading ? null : _handleSignup,
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
                  'Create Account',
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
