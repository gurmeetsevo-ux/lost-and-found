import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onLogout;
  final Function(String) onNavigateToView;
  final Function(Map<String, dynamic>)? onPostSelected;
  final Widget bottomNav;
  final List<Map<String, dynamic>> allPosts;

  const ProfileScreen({
    Key? key,
    this.user,
    required this.onLogout,
    required this.onNavigateToView,
    this.onPostSelected,
    required this.bottomNav,
    required this.allPosts,
  }) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String activeSection = 'main';
  bool isAnonymous = false;
  bool darkMode = false;
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;
  bool isLoading = false;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Map<String, bool> notifications = {
    'newMatches': true,
    'messages': true,
    'claims': true,
    'updates': false,
  };

  Map<String, dynamic> userProfile = {};

  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController locationController;

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  void _initializeProfile() async {
    // Initialize with default values
    userProfile = {
      'name': 'John Doe',
      'email': 'john@example.com',
      'phone': '+91 98765 43210',
      'location': 'Punjab, India',
      'photo': null,
      'isVerified': false,
      'joinDate': DateTime.now().toIso8601String(),
      'isAnonymous': false,
    };

    nameController = TextEditingController(text: userProfile['name']);
    emailController = TextEditingController(text: userProfile['email']);
    phoneController = TextEditingController(text: userProfile['phone']);
    locationController = TextEditingController(text: userProfile['location']);

    // Load data from Firebase
    await _loadUserProfileFromFirebase();
  }

  // Load user profile from Firebase (existing users table)
  Future<void> _loadUserProfileFromFirebase() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          setState(() {
            // Use existing fields from registration
            userProfile['name'] = data['name'] ?? currentUser.displayName ?? 'John Doe';
            userProfile['email'] = data['email'] ?? currentUser.email ?? 'john@example.com';
            userProfile['isVerified'] = data['emailVerified'] ?? currentUser.emailVerified;
            userProfile['photo'] = data['photoURL'] ?? '';

            // Handle createdAt timestamp
            if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
              userProfile['joinDate'] = data['createdAt'].toDate().toIso8601String();
            } else {
              userProfile['joinDate'] = DateTime.now().toIso8601String();
            }

            // Load profile fields (with defaults for new fields)
            userProfile['phone'] = data['phone'] ?? '+91 98765 43210';
            userProfile['location'] = data['location'] ?? 'Punjab, India';
            userProfile['isAnonymous'] = data['isAnonymous'] ?? false;

            // Update controllers
            nameController.text = userProfile['name'];
            emailController.text = userProfile['email'];
            phoneController.text = userProfile['phone'];
            locationController.text = userProfile['location'];
            isAnonymous = userProfile['isAnonymous'];
          });
        }
      }
    } catch (e) {
      print('Error loading user profile: $e');
      _showErrorMessage('Failed to load profile data');
    }
  }

  // Save user profile to Firebase (update existing document)
  Future<void> _saveUserProfileToFirebase() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        Map<String, dynamic> updatedData = {
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'phone': phoneController.text.trim(),
          'location': locationController.text.trim(),
          'isAnonymous': isAnonymous,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Update existing document
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .update(updatedData);

        // Update local state
        setState(() {
          userProfile.addAll(updatedData);
        });

        _showSuccessMessage('Profile saved successfully!');
        navigateToSection('main');
      }
    } catch (e) {
      print('Error saving user profile: $e');
      _showErrorMessage('Failed to save profile. Please try again.');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Upload profile image to Firebase Storage
  Future<String?> _uploadProfileImage(File imageFile) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        String fileName = 'profile_images/${currentUser.uid}.jpg';
        Reference ref = _storage.ref().child(fileName);

        UploadTask uploadTask = ref.putFile(imageFile);
        TaskSnapshot snapshot = await uploadTask;

        String downloadURL = await snapshot.ref.getDownloadURL();
        return downloadURL;
      }
    } catch (e) {
      print('Error uploading image: $e');
      _showErrorMessage('Failed to upload image');
    }
    return null;
  }

  // Show photo selection dialog
  void _showPhotoSelectionDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Profile Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667eea).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.camera_alt, size: 32, color: Color(0xFF667eea)),
                            SizedBox(height: 8),
                            Text('Camera'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667eea).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.photo_library, size: 32, color: Color(0xFF667eea)),
                            SizedBox(height: 8),
                            Text('Gallery'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  // Pick image and upload to Firebase
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          isLoading = true;
        });

        // Upload to Firebase Storage
        String? downloadURL = await _uploadProfileImage(File(pickedFile.path));

        if (downloadURL != null) {
          // Update photoURL in existing document
          User? currentUser = _auth.currentUser;
          if (currentUser != null) {
            await _firestore
                .collection('users')
                .doc(currentUser.uid)
                .update({'photoURL': downloadURL});

            setState(() {
              _profileImage = File(pickedFile.path);
              userProfile['photo'] = downloadURL;
            });

            _showSuccessMessage('Profile photo updated!');
          }
        }
      }
    } catch (e) {
      print('Error selecting image: $e');
      _showErrorMessage('Error selecting image: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void navigateToSection(String sectionName) {
    setState(() {
      activeSection = sectionName;
    });
  }

  // Helper methods for showing messages
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    locationController.dispose();
    super.dispose();
  }

  // Get user posts
  List<Map<String, dynamic>> get userPosts {
    return widget.allPosts.where((post) =>
    post['user'] == userProfile['name']).toList().isNotEmpty
        ? widget.allPosts.where((post) => post['user'] == userProfile['name']).toList()
        : [
      {
        'id': 1,
        'title': 'iPhone 15 Pro',
        'type': 'lost',
        'status': 'active',
        'claims': 2,
        'date': '2024-08-07',
        'image': 'https://images.unsplash.com/photo-1592750475338-74b7b21085ab?w=200'
      },
      {
        'id': 2,
        'title': 'Black Wallet',
        'type': 'found',
        'status': 'claimed',
        'claims': 1,
        'date': '2024-08-05',
        'image': 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=200'
      }
    ];
  }

  // Get user claims
  List<Map<String, dynamic>> get userClaims => [
    {
      'id': 1,
      'itemTitle': 'AirPods Pro',
      'status': 'pending',
      'submittedDate': '2024-08-08',
      'type': 'found'
    },
    {
      'id': 2,
      'itemTitle': 'House Keys',
      'status': 'approved',
      'submittedDate': '2024-08-03',
      'type': 'lost'
    }
  ];

  @override
  Widget build(BuildContext context) {
    switch (activeSection) {
      case 'main':
        return _buildMainProfile();
      case 'personal':
        return _buildPersonalInfo();
      case 'posts':
        return _buildMyPosts();
      case 'claims':
        return _buildMyClaims();
      case 'settings':
        return _buildSettings();
      default:
        return _buildMainProfile();
    }
  }

  Widget _buildMainProfile() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader('Profile', showLogout: true),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildUserInfoSection(),
                        const SizedBox(height: 24),
                        _buildQuickStats(),
                        const SizedBox(height: 24),
                        _buildBadgesSection(),
                        const SizedBox(height: 24),
                        _buildAnonymityToggle(),
                        const SizedBox(height: 24),
                        _buildMenuSections(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.bottomNav,
    );
  }

  Widget _buildPersonalInfo() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader('Personal Info', showSave: true),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildPhotoSection(),
                        const SizedBox(height: 32),
                        _buildFormFields(),
                        const SizedBox(height: 24),
                        _buildVerificationSection(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.bottomNav,
    );
  }

  Widget _buildMyPosts() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader('My Posts', showAdd: true),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildPostsStats(),
                        const SizedBox(height: 24),
                        _buildPostsList(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.bottomNav,
    );
  }

  Widget _buildMyClaims() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader('My Claims'),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildClaimsSummary(),
                        const SizedBox(height: 24),
                        _buildClaimsList(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.bottomNav,
    );
  }

  Widget _buildSettings() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader('Settings'),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildNotificationsSettings(),
                        const SizedBox(height: 24),
                        _buildPreferencesSettings(),
                        const SizedBox(height: 24),
                        _buildHelpSection(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.bottomNav,
    );
  }

  Widget _buildHeader(String title, {bool showLogout = false, bool showSave = false, bool showAdd = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (activeSection == 'main') {
                widget.onNavigateToView('home');
              } else {
                navigateToSection('main');
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (showLogout)
            GestureDetector(
              onTap: widget.onLogout,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else if (showSave)
            GestureDetector(
              onTap: isLoading ? null : _saveUserProfileToFirebase,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(isLoading ? 0.1 : 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    else
                      const Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            )
          else if (showAdd)
              GestureDetector(
                onTap: () => widget.onNavigateToView('add'),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              )
            else
              const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildUserInfoSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _profileImage != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(_profileImage!, fit: BoxFit.cover),
                )
                    : userProfile['photo'] != null && userProfile['photo'].toString().isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    userProfile['photo'],
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const CircularProgressIndicator();
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.person, size: 32, color: Color(0xFF667eea));
                    },
                  ),
                )
                    : const Icon(Icons.person, size: 32, color: Color(0xFF667eea)),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: isLoading ? null : _showPhotoSelectionDialog,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isLoading
                        ? const Padding(
                      padding: EdgeInsets.all(6),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isAnonymous ? 'Anonymous User' : userProfile['name'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2d3748),
                        ),
                      ),
                    ),
                    Icon(
                      userProfile['isVerified'] ? Icons.check_circle : Icons.warning,
                      color: userProfile['isVerified'] ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  userProfile['email'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Member since ${DateTime.parse(userProfile['joinDate']).year}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(child: _buildStatCard(userPosts.length.toString(), 'Posts')),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(userClaims.length.toString(), 'Claims')),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('4.8', 'Rating')),
      ],
    );
  }

  Widget _buildStatCard(String number, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF667eea).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF667eea),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Achievements',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2d3748),
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              if (userProfile['isVerified'])
                _buildBadgeItem(Icons.check_circle, 'Verified', 'Account verified', Colors.green),

              if (userPosts.isNotEmpty)
                _buildBadgeItem(Icons.description, 'Active Poster', '${userPosts.length}+ posts', Colors.blue),

              if (userClaims.where((c) => c['status'] == 'approved').isNotEmpty)
                _buildBadgeItem(Icons.check_circle, 'Helper', 'Successful claims', Colors.orange),

              _buildBadgeItem(Icons.shield, 'Trusted', 'Follows guidelines', Colors.purple),

              if (DateTime.now().difference(DateTime.parse(userProfile['joinDate'])).inDays > 30)
                _buildBadgeItem(Icons.emoji_events, 'Veteran', '30+ days member', Colors.amber),

              _buildBadgeItem(Icons.person, 'Community Member', 'Welcome to the community!', Colors.teal),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.emoji_events, size: 16),
              label: const Text('View All Achievements'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea).withOpacity(0.1),
                foregroundColor: const Color(0xFF667eea),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeItem(IconData icon, String name, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2d3748),
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnonymityToggle() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Anonymous Mode',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2d3748),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hide your identity when posting items',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isAnonymous,
            onChanged: (value) {
              setState(() {
                isAnonymous = value;
              });
            },
            activeColor: const Color(0xFF667eea),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSections() {
    return Column(
      children: [
        _buildMenuSection(
          'Account',
          [
            _buildMenuItem(Icons.person, 'Personal Info', 'Manage your profile details', () => navigateToSection('personal')),
            _buildMenuItem(Icons.description, 'My Posts', '${userPosts.length} active posts', () => navigateToSection('posts')),
            _buildMenuItem(Icons.check_circle, 'My Claims', '${userClaims.length} claims submitted', () => navigateToSection('claims')),
          ],
        ),
        const SizedBox(height: 24),
        _buildMenuSection(
          'Preferences',
          [
            _buildMenuItem(Icons.settings, 'Settings', 'Notifications, privacy & more', () => navigateToSection('settings')),
            _buildMenuItem(Icons.help, 'Help & Support', 'FAQ, contact & guidelines', () {}),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuSection(String title, List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2d3748),
              ),
            ),
          ),
          ...items,
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF667eea), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2d3748),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
          ),
          child: _profileImage != null
              ? ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Image.file(
              _profileImage!,
              fit: BoxFit.cover,
            ),
          )
              : userProfile['photo'] != null && userProfile['photo'].toString().isNotEmpty
              ? ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Image.network(
              userProfile['photo'],
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const CircularProgressIndicator();
              },
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.person, size: 48, color: Color(0xFF667eea));
              },
            ),
          )
              : const Icon(Icons.person, size: 48, color: Color(0xFF667eea)),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: isLoading ? null : _showPhotoSelectionDialog,
          icon: const Icon(Icons.camera_alt, size: 16),
          label: const Text('Change Photo'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF667eea).withOpacity(0.1),
            foregroundColor: const Color(0xFF667eea),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        _buildFormField('Full Name', nameController, Icons.person),
        const SizedBox(height: 16),
        _buildFormField('Email Address', emailController, Icons.mail),
        const SizedBox(height: 16),
        _buildFormField('Phone Number', phoneController, Icons.phone),
        const SizedBox(height: 16),
        _buildFormField('Location', locationController, Icons.location_on),
      ],
    );
  }

  Widget _buildFormField(String label, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: label == 'Phone Number' ? TextInputType.phone : TextInputType.text,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey[600]),
            suffixIcon: label == 'Email Address'
                ? Icon(
              userProfile['isVerified'] ? Icons.check_circle : Icons.warning,
              color: userProfile['isVerified'] ? Colors.green : Colors.orange,
              size: 18,
            )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: userProfile['isVerified']
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: userProfile['isVerified'] ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Verification',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2d3748),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                userProfile['isVerified'] ? Icons.check_circle : Icons.warning,
                color: userProfile['isVerified'] ? Colors.green : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userProfile['isVerified'] ? 'Verified Account' : 'Unverified Account',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2d3748),
                      ),
                    ),
                    Text(
                      userProfile['isVerified']
                          ? 'Your account has been verified'
                          : 'Verify your email to increase trust',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!userProfile['isVerified']) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Verify Now'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPostsStats() {
    final activePosts = userPosts.where((p) => p['status'] == 'active').length;
    final claimedPosts = userPosts.where((p) => p['status'] == 'claimed').length;
    int totalClaims = 0;
    for (var post in userPosts) {
      totalClaims += (post['claims'] as int?) ?? 0;
    }

    return Row(
      children: [
        Expanded(child: _buildStatCard(activePosts.toString(), 'Active')),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(claimedPosts.toString(), 'Claimed')),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(totalClaims.toString(), 'Total Claims')),
      ],
    );
  }

  Widget _buildPostsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Posts',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2d3748),
          ),
        ),
        const SizedBox(height: 16),
        ...userPosts.map((post) => _buildPostCard(post)),
      ],
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: post['image'] != null
                      ? DecorationImage(
                    image: NetworkImage(post['image']),
                    fit: BoxFit.cover,
                  )
                      : null,
                  color: post['image'] == null ? Colors.grey[200] : null,
                ),
                child: post['image'] == null
                    ? const Icon(Icons.image, color: Colors.grey)
                    : Stack(
                  children: [
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: post['type'] == 'lost' ? Colors.red : Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          post['type'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            post['title'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2d3748),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: post['status'] == 'active' ? Colors.green : Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            post['status'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${post['date']} • ${post['claims'] ?? 0} claims',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPostActionButton(Icons.visibility, 'View', () {
                if (widget.onPostSelected != null) {
                  widget.onPostSelected!(post);
                  widget.onNavigateToView('detail');
                }
              }),
              const SizedBox(width: 8),
              _buildPostActionButton(Icons.edit, 'Edit', () {}),
              const SizedBox(width: 8),
              _buildPostActionButton(Icons.delete, 'Delete', () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostActionButton(IconData icon, String label, VoidCallback onPressed) {
    return Expanded(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: const Color(0xFF667eea)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF667eea),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClaimsSummary() {
    final activeClaims = userClaims.where((c) => c['status'] == 'pending').length;
    final approvedClaims = userClaims.where((c) => c['status'] == 'approved').length;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'Active Claims',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  activeClaims.toString(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'Approved',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  approvedClaims.toString(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClaimsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Claim History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2d3748),
          ),
        ),
        const SizedBox(height: 16),
        ...userClaims.map((claim) => _buildClaimCard(claim)),
      ],
    );
  }

  Widget _buildClaimCard(Map<String, dynamic> claim) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      claim['itemTitle'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2d3748),
                      ),
                    ),
                    Text(
                      'Claim for ${claim['type']} item',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: claim['status'] == 'approved' ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      claim['status'] == 'approved' ? Icons.check_circle : Icons.schedule,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      claim['status'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Submitted: ${claim['submittedDate']}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          if (claim['status'] == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.message, size: 16),
                    label: const Text('Message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Cancel Claim'),
                  ),
                ),
              ],
            ),
          ],
          if (claim['status'] == 'approved') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Claim approved! Contact the poster to arrange pickup.',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationsSettings() {
    return _buildSettingsSection(
      'Notifications',
      [
        _buildSettingToggle(
          'New Matches',
          'When someone finds your lost item',
          notifications['newMatches']!,
              (value) => setState(() => notifications['newMatches'] = value),
        ),
        _buildSettingToggle(
          'Messages',
          'New messages and replies',
          notifications['messages']!,
              (value) => setState(() => notifications['messages'] = value),
        ),
        _buildSettingToggle(
          'Claims',
          'When someone claims your found item',
          notifications['claims']!,
              (value) => setState(() => notifications['claims'] = value),
        ),
        _buildSettingToggle(
          'App Updates',
          'News and feature announcements',
          notifications['updates']!,
              (value) => setState(() => notifications['updates'] = value),
        ),
      ],
    );
  }

  Widget _buildPreferencesSettings() {
    return _buildSettingsSection(
      'Preferences',
      [
        _buildSettingDropdown('Language', 'App language', 'English'),
        _buildSettingToggle(
          'Dark Mode',
          'Use dark theme',
          darkMode,
              (value) => setState(() => darkMode = value),
        ),
      ],
    );
  }

  Widget _buildHelpSection() {
    return _buildSettingsSection(
      'Help & Support',
      [
        _buildSettingButton(Icons.help, 'FAQ', 'Frequently asked questions', () {}),
        _buildSettingButton(Icons.message, 'Contact Support', 'Get help from our team', () {}),
        _buildSettingButton(Icons.shield, 'Safety Guidelines', 'Stay safe when meeting', () {}),
        _buildSettingButton(Icons.description, 'Community Guidelines', 'Rules and best practices', () {}),
      ],
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> items) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2d3748),
            ),
          ),
          const SizedBox(height: 16),
          ...items,
        ],
      ),
    );
  }

  Widget _buildSettingToggle(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2d3748),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF667eea),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingDropdown(String title, String subtitle, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2d3748),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: value,
            onChanged: (String? newValue) {},
            items: ['English', 'Español', 'Français']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingButton(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF667eea), size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2d3748),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
