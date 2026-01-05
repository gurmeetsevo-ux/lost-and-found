import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'welcome_screen.dart';
import 'signup_screen.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'profile_screen.dart';
import 'filter_modal.dart';
import 'add_post_screen.dart';
import 'services/algolia_manual_service.dart';
import 'post_detail_screen.dart';
import 'map_screen.dart';
import 'theme_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  /// Start Algolia
  AlgoliaManualService.initialize();

  runApp(const LostAndFoundApp());
}


class LostAndFoundApp extends StatelessWidget {
  const LostAndFoundApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Lost & Found',
            theme: themeProvider.themeData,
            home: const AppNavigator(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class AppNavigator extends StatefulWidget {
  const AppNavigator({Key? key}) : super(key: key);

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  String currentView = 'welcome';
  Map<String, dynamic>? user;

  // Home screen state variables
  String searchQuery = '';
  String selectedCategory = 'all';
  String postType = 'lost';

  // Filter Modal state variables
  bool _showFilterModal = false;
  Map<String, dynamic> _currentFilters = {};

  // Categories list - will be fetched from database
  List<String> categories = ['all']; // Start with 'all' as default
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    // Fetch categories from database when app initializes
    _fetchCategories();
  }

  // Add this method to fetch categories from Algolia
  Future<void> _fetchCategories() async {
    try {
      print('🗂️ MAIN: Fetching categories from Algolia...');
      final algoliaCategories = await AlgoliaManualService.fetchCategoriesFromIndex();
      
      // Remove 'All' and 'all' from algoliaCategories and add our 'all' at the beginning
      final filteredCategories = algoliaCategories
          .where((category) => category.toLowerCase() != 'all')
          .toList();
      
      setState(() {
        categories = ['all', ...filteredCategories];
        _isLoadingCategories = false;
      });
      
      print('🗂️ MAIN: Successfully loaded ${categories.length} categories');
    } catch (e) {
      print('❌ MAIN: Failed to fetch categories: $e');
      setState(() {
        // Fallback to default categories
        categories = [
          'all', 'Electronics', 'Wallet/Bag', 'Keys', 'Documents', 'Clothing', 'Other'
        ];
        _isLoadingCategories = false;
      });
    }
  }

  // ✅ Mock data for posts
  List<Map<String, dynamic>> allPosts = [
    {
      'id': 1,
      'type': 'lost',
      'title': 'iPhone 15 Pro',
      'description': 'Lost my blue iPhone 15 Pro near Central Park',
      'category': 'Electronics',
      'location': 'Central Park, NYC',
      'date': '2024-08-07',
      'image': 'https://images.unsplash.com/photo-1592750475338-74b7b21085ab?w=200&h=200&fit=crop',
      'user': 'John Doe',
      'status': 'active',
      'claims': 2
    },
    {
      'id': 2,
      'type': 'found',
      'title': 'Black Wallet',
      'description': 'Found a black leather wallet with cards',
      'category': 'Wallet/Bag',
      'location': 'Times Square, NYC',
      'date': '2024-08-06',
      'image': 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=200&h=200&fit=crop',
      'user': 'John Doe',
      'status': 'active',
      'claims': 0
    },
    {
      'id': 3,
      'type': 'lost',
      'title': 'House Keys',
      'description': 'Lost my house keys with blue keychain',
      'category': 'Keys',
      'location': 'Brooklyn Bridge, NYC',
      'date': '2024-08-05',
      'image': 'https://images.unsplash.com/photo-1582139329536-e7284fece509?w=200&h=200&fit=crop',
      'user': 'Sarah Wilson',
      'status': 'claimed',
      'claims': 1
    },
    {
      'id': 4,
      'type': 'found',
      'title': 'Blue Backpack',
      'description': 'Found blue backpack with school supplies',
      'category': 'Clothing',
      'location': 'Central Station, NYC',
      'date': '2024-08-04',
      'image': 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=200&h=200&fit=crop',
      'user': 'John Doe',
      'status': 'active',
      'claims': 1
    }
  ];

  void setCurrentView(String view) {
    setState(() {
      currentView = view;
    });
  }

  void login(Map<String, dynamic> userData, [String? token]) async {
    print('🎯 === MAIN LOGIN CALLBACK RECEIVED ===');
    print('🎯 userData: $userData');
    print('🎯 token: ${token != null ? 'present' : 'null'}');
    
    // ✅ SIMPLIFIED VALIDATION: Check basic requirements
    if (userData.isEmpty) {
      print('❌ Login failed: User data is empty');
      return;
    }
    
    // ✅ DIRECT UID CHECK: Get UID directly from userData
    final String? uid = userData['uid'];
    final String? email = userData['email'];
    
    print('🔍 Direct field check:');
    print('🔍 uid: $uid');
    print('🔍 email: $email');
    
    if (uid == null || uid.isEmpty) {
      print('❌ Login failed: UID is null or empty');
      return;
    }
    
    if (email == null || email.isEmpty) {
      print('❌ Login failed: Email is null or empty');
      return;
    }
    
    // ✅ FETCH LATEST USER DATA FROM FIRESTORE TO GET UPDATED SETTINGS
    Map<String, dynamic>? firestoreUserData = await _fetchUserFromFirestore(uid);
    
    // ✅ MERGE USER DATA: Use Firestore data as primary, fallback to original data
    Map<String, dynamic> finalUserData = {
      ...userData, // Start with original data
      if (firestoreUserData != null) ...firestoreUserData, // Override with Firestore data
    };
    
    // ✅ SUCCESS: Update app state
    setState(() {
      user = finalUserData;
      currentView = 'home';
    });
    
    print('✅ Login successful for user: $email (UID: $uid)');
    print('✅ User data merged with Firestore: $finalUserData');
    print('✅ Navigated to: $currentView');
  }
  
  // Helper method to fetch user data from Firestore
  Future<Map<String, dynamic>?> _fetchUserFromFirestore(String uid) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (doc.exists) {
        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          // Ensure we have essential fields from the original user data
          return data;
        }
      }
    } catch (e) {
      print('⚠️ Error fetching user from Firestore: $e');
    }
    return null;
  }

  // ✅ NEW: Handle adding new posts
  void handleAddPost(Map<String, dynamic> newPostData) {
    try {
      // Validate required fields
      if (newPostData['title']?.isEmpty ?? true) {
        throw Exception('Title is required');
      }
      if (newPostData['description']?.isEmpty ?? true) {
        throw Exception('Description is required');
      }
      if (newPostData['location']?.isEmpty ?? true) {
        throw Exception('Location is required');
      }

      // Add to posts list
      setState(() {
        allPosts.add({
          'id': allPosts.length + 1,
          'type': newPostData['postType'] ?? postType,
          'title': newPostData['title'],
          'description': newPostData['description'],
          'category': newPostData['category'] ?? 'Other',
          'location': newPostData['location'],
          'date': newPostData['date'] ?? DateTime.now().toIso8601String().split('T')[0],
          'time': newPostData['time'],
          'image': newPostData['image'], // This will be the file path
          'user': user?['name'] ?? 'Unknown User',
          'status': 'active',
          'claims': 0,
          'notes': newPostData['notes'],
        });
      });

      // Success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${newPostData['postType'] == 'lost' ? 'Lost' : 'Found'} item posted successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Navigate back to home
      setCurrentView('home');

    } catch (e) {
      // Error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error posting item: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Add this method to your _AppNavigatorState class
  void _showPostDetailModal(Map<String, dynamic> post) {
    print('📱 MAIN: Opening full-screen post detail for: ${post['title']}');

    // Navigate to full-screen detail page instead of modal
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(post: post),
      ),
    );
  }

  // Add these helper methods to handle actions
  void _handleContactOwner(Map<String, dynamic> post) {
    // You can implement:
    // 1. Open messaging/chat screen
    // 2. Send notification to post owner
    // 3. Open email/phone contact

    print('📞 MAIN: Contacting owner of: ${post['title']}');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contact request sent for: ${post['title']}'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            // Navigate to messages/chat screen
            setCurrentView('messages'); // You can create this view
          },
        ),
      ),
    );
  }

  void _handleClaimItem(Map<String, dynamic> post) {
    // You can implement:
    // 1. Submit claim form
    // 2. Send notification to post owner
    // 3. Create claim record in database

    print('🏷️ MAIN: Claiming item: ${post['title']}');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Claim ${post['title']}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to claim this ${post['type']} item?'),
              const SizedBox(height: 16),
              Text(
                'This will notify the owner and they may contact you for verification.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close modal

                // Process the claim
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Claim submitted for: ${post['title']}'),
                    backgroundColor: Colors.green,
                  ),
                );

                // You can add the claim to your database here
                // and update the post status
              },
              child: const Text('Submit Claim'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
  // Filter Modal methods
  void _showFilter() {
    setState(() {
      _showFilterModal = true;
    });
  }

  void _hideFilter() {
    setState(() {
      _showFilterModal = false;
    });
  }

  void _applyFilters(Map<String, dynamic> filters) {
    setState(() {
      _currentFilters = filters;
      _showFilterModal = false;
    });

    print('Applied filters: $filters');
    setCurrentView('search');
  }

  Widget _buildFilterChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF667eea).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF667eea).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF667eea),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              setState(() {
                _currentFilters.clear();
              });
            },
            child: const Icon(
              Icons.close,
              size: 14,
              color: Color(0xFF667eea),
            ),
          ),
        ],
      ),
    );
  }

  // Bottom Navigation Widget
  Widget buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey, width: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.home,
                  label: 'Home',
                  view: 'home',
                  isActive: currentView == 'home',
                ),
                _buildNavItem(
                  icon: Icons.search,
                  label: 'Search',
                  view: 'search',
                  isActive: currentView == 'search',
                ),
                _buildAddButton(),
                _buildNavItem(
                  icon: Icons.map,
                  label: 'Map',
                  view: 'map',
                  isActive: currentView == 'map',
                ),
                _buildNavItem(
                  icon: Icons.person,
                  label: 'Profile',
                  view: 'profile',
                  isActive: currentView == 'profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required String view,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () => setCurrentView(view),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? Colors.blue : Colors.grey,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.blue : Colors.grey,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: () => setCurrentView('add'),
      child: Transform.scale(
        scale: 1.1,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.add,
            size: 32,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Enhanced Home Screen Widget
  Widget _buildHomeScreen() {
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
              _buildMainHeader(),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPrimaryActionsSection(),
                        const SizedBox(height: 32),
                        _buildSearchSection(),
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
      bottomNavigationBar: buildBottomNav(),
    );
  }

  Widget _buildMainHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${user?.containsKey('isAnonymous') == true && user!['isAnonymous'] == true ? 'Anonymous User' : user?['name']?.split(' ')[0] ?? 'User'}! 👋',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'What can we help you find today?',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => setCurrentView('notifications'),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(Icons.notifications, color: Colors.white, size: 20),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text('3', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => setCurrentView('profile'),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Center(
                    child: Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Report an Item',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2d3748),
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            _buildActionButton(
              title: 'Lost Item',
              subtitle: 'Report something you\'ve lost',
              icon: Icons.search,
              color: Colors.red,
              onTap: () {
                setState(() => postType = 'lost');
                setCurrentView('add');
              },
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              title: 'Found Item',
              subtitle: 'Report something you\'ve found',
              icon: Icons.check_circle,
              color: Colors.green,
              onTap: () {
                setState(() => postType = 'found');
                setCurrentView('add');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: color.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Find Items',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2d3748),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => setCurrentView('search'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey!),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.grey, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    searchQuery.isEmpty
                        ? 'Search for lost or found items...'
                        : searchQuery,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _showFilter,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.tune, color: Colors.grey[600], size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Show loading indicator while fetching categories
        if (_isLoadingCategories)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          )
        else
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.take(5).length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isActive = selectedCategory == category;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => selectedCategory = category);
                      setCurrentView('search');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF667eea)
                            : const Color(0xFF667eea).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF667eea).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        category == 'all' ? 'All Items' : category,
                        style: TextStyle(
                          color: isActive ? Colors.white : const Color(0xFF667eea),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 24),
        Container(
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
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            'Use the search above to find lost or found items in your area',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildMainAppContent(),
        if (_showFilterModal)
          FilterModal(
            onClose: _hideFilter,
            onFilter: _applyFilters,
            initialFilters: _currentFilters,
          ),
      ],
    );
  }

  Widget _buildMainAppContent() {
    if (currentView == 'welcome') {
      return WelcomeScreen(
        onNavigateToSignup: () => setCurrentView('signup'),
        onNavigateToLogin: () => setCurrentView('login'),
        onLogin: login,
      );
    }

    if (currentView == 'signup') {
      return SignupScreen(
        onNavigateToWelcome: () => setCurrentView('welcome'),
        onNavigateToLogin: () => setCurrentView('login'),
        onSignup: login,
      );
    }

    if (currentView == 'login') {
      return LoginScreen(
        onNavigateToWelcome: () => setCurrentView('welcome'),
        onNavigateToSignup: () => setCurrentView('signup'),
        onLogin: login,
      );
    }

    if (currentView == 'home') {
      return _buildHomeScreen();
    }

    if (currentView == 'search') {
      print('🧭 MAIN: Creating SearchScreen with Algolia integration...');
      return SearchScreen(
        onNavigateBack: () {
          print('🧭 MAIN: Returning from SearchScreen to home');
          setCurrentView('home');
        },
        bottomNav: buildBottomNav(),
        onPostSelected: (post) {
          print('🧭 MAIN: Post selected from Algolia search:');
          print('   📝 Title: ${post['title']}');
          print('   🆔 ID: ${post['id']}');
          print('   📂 Category: ${post['category']}');

          // Show the detailed post modal
          _showPostDetailModal(post);
        },
      );
    }
    // ✅ REPLACED: This is where the AddPostScreen gets integrated
    if (currentView == 'add') {
      return AddPostScreen(
        postType: postType,
        setPostType: (String type) {
          setState(() {
            postType = type;
          });
        },
        onAddPost: handleAddPost,
        onBack: () => setCurrentView('home'),
        user: user,
      );
    }

    if (currentView == 'notifications') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Notifications Screen\n(Coming Soon)'),
        ),
        bottomNavigationBar: buildBottomNav(),
      );
    }

    if (currentView == 'map') {
      return MapScreen(
        onNavigateBack: () => setCurrentView('home'),
        bottomNav: buildBottomNav(),
        onItemSelected: (item) {
          // Navigate to post detail screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailScreen(post: item),
            ),
          );
        },
      );
    }

    if (currentView == 'profile') {
      return ProfileScreen(
        user: user,
        onLogout: () => setState(() {
          user = null;
          currentView = 'welcome';
        }),
        onNavigateToView: setCurrentView,
        onPostSelected: (post) {
          print('Selected post: $post');
        },
        onUpdateUser: (updatedUser) {
          setState(() {
            user = updatedUser;
          });
        },
        bottomNav: buildBottomNav(),
        allPosts: allPosts,
      );
    }

    return WelcomeScreen(
      onNavigateToSignup: () => setCurrentView('signup'),
      onNavigateToLogin: () => setCurrentView('login'),
      onLogin: login,
    );
  }
}
