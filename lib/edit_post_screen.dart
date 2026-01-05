import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'services/algolia_manual_service.dart';
import 'location_picker_screen.dart';

class EditPostScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final String postId;
  final Function(Map<String, dynamic>) onPostUpdated;
  final VoidCallback onBack;
  final Map<String, dynamic>? user;

  const EditPostScreen({
    Key? key,
    required this.post,
    required this.postId,
    required this.onPostUpdated,
    required this.onBack,
    this.user,
  }) : super(key: key);

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // Controllers
  final TextEditingController _locationController = TextEditingController();

  File? _image;
  final picker = ImagePicker();
  bool _isSubmitting = false;
  bool _isGettingLocation = false;

  // Check user's anonymous mode setting and return appropriate name
  String _getUserNameForPost() {
    // If no user is logged in, return Anonymous User
    if (widget.user == null || widget.user!['uid'] == null) {
      return 'Anonymous User';
    }
    
    // Check if user has enabled anonymous mode in their profile
    bool isAnonymousModeEnabled = widget.user?['isAnonymous'] ?? false;
    
    // If anonymous mode is enabled, return Anonymous User; otherwise return actual name
    if (isAnonymousModeEnabled) {
      return 'Anonymous User';
    } else {
      return widget.user?['name'] ?? 'User';
    }
  }

  // Form fields
  Map<String, dynamic> editedPost = {};

  @override
  void initState() {
    super.initState();
    
    // Initialize with existing post data
    // Handle location field properly - extract address if it's a Map
    String locationText = '';
    if (widget.post['location'] is Map) {
      // If location is a Map, extract the address
      locationText = widget.post['location']['address'] ?? '';
    } else if (widget.post['location'] is String) {
      // If location is already a String, use it directly
      locationText = widget.post['location'] ?? '';
    }

    editedPost = {
      'title': widget.post['title'] ?? '',
      'category': widget.post['category'] ?? 'Electronics',
      'description': widget.post['description'] ?? '',
      'date': widget.post['date'] ?? DateTime.now().toIso8601String().split('T')[0],
      'time': widget.post['time'] ?? '',
      'location': locationText, // Use the extracted address string
      'status': widget.post['status'] ?? 'active',
      'notes': widget.post['notes'] ?? '',
      'type': widget.post['type'] ?? 'lost',
    };

    // Initialize location controller with existing location
    _locationController.text = editedPost['location'];

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    _slideController.forward();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Location functionality - AUTO-FILL IMPLEMENTATION
  Future<void> _useCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationError('Location services are disabled. Please enable them in settings.');
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationError('Location permissions are denied. Please grant location access.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationError('Location permissions are permanently denied. Please enable them in app settings.');
        return;
      }

      // Show loading message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Detecting your current location...'),
            ],
          ),
          backgroundColor: Color(0xFF667eea),
          duration: Duration(seconds: 3),
        ),
      );

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );

      print('📍 Current Position: Lat=${position.latitude}, Lng=${position.longitude}');

      // Get address from coordinates using reverse geocoding
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Build a readable address
        List<String> addressParts = [];

        if (place.street?.isNotEmpty == true) addressParts.add(place.street!);
        if (place.locality?.isNotEmpty == true) addressParts.add(place.locality!);
        if (place.administrativeArea?.isNotEmpty == true) addressParts.add(place.administrativeArea!);
        if (place.postalCode?.isNotEmpty == true) addressParts.add(place.postalCode!);

        String fullAddress = addressParts.join(', ');

        setState(() {
          editedPost['location'] = fullAddress;
          _locationController.text = fullAddress;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location updated: $fullAddress'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showLocationError('Could not determine your location. Please enter manually.');
      }
    } catch (e) {
      print('❌ Location Error: $e');
      _showLocationError('Failed to get location. Please try again or enter manually.');
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  // Show location error
  void _showLocationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Image selection
  Future<void> _selectImage() async {
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxHeight: 800,
        maxWidth: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('❌ Image Selection Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Camera capture
  Future<void> _captureImage() async {
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxHeight: 800,
        maxWidth: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('❌ Camera Capture Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to capture image'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Upload image to Firebase Storage
  Future<String?> _uploadImage() async {
    if (_image == null) return null;

    try {
      String fileName = 'posts/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(_image!);
      TaskSnapshot snapshot = await uploadTask;

      String downloadURL = await snapshot.ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      print('❌ Image Upload Error: $e');
      return null;
    }
  }

  // Update post
  Future<void> _updatePost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Upload image first (if exists and changed)
      String? imageUrl;
      if (_image != null) {
        imageUrl = await _uploadImage();
      } else {
        // Keep the existing image URL if no new image is selected
        imageUrl = widget.post['imageUrl'];
      }

      // Get user's anonymous mode setting
      bool userAnonymousMode = widget.user?['isAnonymous'] ?? false;

      // Prepare location data - preserve original if it exists
      Map<String, dynamic>? locationData;
      
      // Determine if location is a Map or String for comparison
      String? originalLocationAddress;
      if (widget.post['location'] is Map) {
        originalLocationAddress = widget.post['location']['address'] ?? '';
        // Preserve the original location data structure completely
        locationData = Map<String, dynamic>.from(widget.post['location']);
      } else if (widget.post['location'] is String) {
        originalLocationAddress = widget.post['location'];
        // Convert string location to proper Map structure with null coordinates
        locationData = {
          'address': widget.post['location'],
          'coordinates': null,
          'accuracy': null,
        };
      } else {
        // Handle null or unexpected location type
        originalLocationAddress = '';
        locationData = {
          'address': editedPost['location'],
          'coordinates': null,
          'accuracy': null,
        };
      }

      // Helper function to preserve original coordinates
      Map<String, dynamic> _createLocationDataWithPreservedCoordinates() {
        Map<String, dynamic>? originalCoordinates;
        var originalLocationData = widget.post['location'];
        
        if (originalLocationData != null && 
            originalLocationData is Map && 
            originalLocationData['coordinates'] != null && 
            originalLocationData['coordinates'] is Map) {
          // Create a copy of the original coordinates
          originalCoordinates = Map<String, dynamic>.from(originalLocationData['coordinates']);
        }
        
        // Return location data preserving coordinates if they exist
        return {
          'address': editedPost['location'],
          'coordinates': originalCoordinates, // Preserve original coordinates if they exist
          'accuracy': (originalLocationData != null && originalLocationData is Map) ? originalLocationData['accuracy'] ?? null : null,
        };
      }

      // If location was updated manually, update both address and coordinates via geocoding
      if (editedPost['location'] != originalLocationAddress) {
        // User changed the location text, we need to geocode the new address to get coordinates
        try {
          // Geocode the new address to get coordinates using geocoding package
          // Import the geolocator package's locationFromAddress function
          List<Location> locations = await locationFromAddress(editedPost['location']);
          if (locations.isNotEmpty) {
            Location location = locations[0];
            
            // Update the location data with new address and newly geocoded coordinates
            locationData = {
              'address': editedPost['location'],
              'coordinates': {
                'latitude': location.latitude,
                'longitude': location.longitude,
              },
              'accuracy': null, // Location doesn't have accuracy property
            };
          } else {
            // If geocoding fails, preserve original coordinates if they exist
            locationData = _createLocationDataWithPreservedCoordinates();
          }
        } catch (e) {
          print('❌ Geocoding error for address "${editedPost['location']}": $e');
          // If geocoding fails, preserve original coordinates if they exist
          locationData = _createLocationDataWithPreservedCoordinates();
        }
      }

      // Prepare updated post data
      Map<String, dynamic> updatedPostData = {
        'title': editedPost['title'],
        'category': editedPost['category'],
        'description': editedPost['description'],
        'date': editedPost['date'],
        'time': editedPost['time'],
        'location': locationData, // Use the properly structured location data
        'status': editedPost['status'],
        'notes': editedPost['notes'] ?? '',
        'type': editedPost['type'],
        'imageUrl': imageUrl,
        'userName': userAnonymousMode ? 'Anonymous User' : (widget.user?['name'] ?? 'User'),
        // Don't update userId, userEmail, or other user-specific fields
      };

      // Update the post in both Firestore and Algolia
      await AlgoliaManualService.updatePost(widget.postId, updatedPostData);

      // Success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Call the callback to update UI
      widget.onPostUpdated({
        ...widget.post,
        ...updatedPostData,
        'id': widget.postId, // Ensure ID is included
      });

      // Navigate back
      widget.onBack();

    } catch (e) {
      print('❌ Update Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
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
            colors: [Color(0xFF667eea), Color(0xFF764ba2)], // Same gradient as ProfileScreen
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with back button and save button
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
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
                        'Edit Post',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    GestureDetector(
                      onTap: _isSubmitting ? null : _updatePost,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(_isSubmitting ? 0.1 : 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isSubmitting)
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
                    ),
                  ],
                ),
              ),
              // Main content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: AnimatedBuilder(
                    animation: _slideController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: _slideAnimation.value,
                        child: child,
                      );
                    },
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          children: [
                            // Post Type Selection
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Post Type',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2d3748),
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              editedPost['type'] = 'lost';
                                            });
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(vertical: 12),
                                            decoration: BoxDecoration(
                                              color: editedPost['type'] == 'lost'
                                                  ? Color(0xFF667eea).withOpacity(0.1)
                                                  : Colors.grey[100],
                                              borderRadius: BorderRadius.horizontal(
                                                left: Radius.circular(8),
                                                right: editedPost['type'] == 'found'
                                                    ? Radius.circular(0)
                                                    : Radius.circular(8),
                                              ),
                                              border: Border.all(
                                                color: editedPost['type'] == 'lost'
                                                    ? Color(0xFF667eea)
                                                    : Colors.grey[300]!,
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Icon(
                                                  Icons.search,
                                                  color: editedPost['type'] == 'lost'
                                                      ? Color(0xFF667eea)
                                                      : Colors.grey,
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Lost',
                                                  style: TextStyle(
                                                    color: editedPost['type'] == 'lost'
                                                        ? Color(0xFF667eea)
                                                        : Colors.grey[600],
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              editedPost['type'] = 'found';
                                            });
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(vertical: 12),
                                            decoration: BoxDecoration(
                                              color: editedPost['type'] == 'found'
                                                  ? Color(0xFF667eea).withOpacity(0.1)
                                                  : Colors.grey[100],
                                              borderRadius: BorderRadius.horizontal(
                                                left: editedPost['type'] == 'lost'
                                                    ? Radius.circular(0)
                                                    : Radius.circular(8),
                                                right: Radius.circular(8),
                                              ),
                                              border: Border.all(
                                                color: editedPost['type'] == 'found'
                                                    ? Color(0xFF667eea)
                                                    : Colors.grey[300]!,
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Icon(
                                                  Icons.visibility,
                                                  color: editedPost['type'] == 'found'
                                                      ? Color(0xFF667eea)
                                                      : Colors.grey,
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Found',
                                                  style: TextStyle(
                                                    color: editedPost['type'] == 'found'
                                                        ? Color(0xFF667eea)
                                                        : Colors.grey[600],
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 20),

                            // Title Input
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Title *',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2d3748),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  TextFormField(
                                    initialValue: editedPost['title'],
                                    decoration: InputDecoration(
                                      hintText: 'Enter item title',
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
                                        borderSide: BorderSide(
                                          color: Color(0xFF667eea),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter a title';
                                      }
                                      return null;
                                    },
                                    onChanged: (value) {
                                      setState(() {
                                        editedPost['title'] = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 20),

                            // Category Selection
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Category *',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2d3748),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    value: editedPost['category'],
                                    decoration: InputDecoration(
                                      hintText: 'Select category',
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
                                        borderSide: BorderSide(
                                          color: Color(0xFF667eea),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    items: [
                                      'Electronics',
                                      'Wallet/Bag',
                                      'Keys',
                                      'Documents',
                                      'Clothing',
                                      'Other',
                                    ].map((category) {
                                      return DropdownMenuItem(
                                        value: category,
                                        child: Text(category),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        editedPost['category'] = value!;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 20),

                            // Description
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Description *',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2d3748),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  TextFormField(
                                    initialValue: editedPost['description'],
                                    maxLines: 4,
                                    decoration: InputDecoration(
                                      hintText: 'Describe the item',
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
                                        borderSide: BorderSide(
                                          color: Color(0xFF667eea),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please describe the item';
                                      }
                                      return null;
                                    },
                                    onChanged: (value) {
                                      setState(() {
                                        editedPost['description'] = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 20),

                            // Location
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Location *',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2d3748),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xFF667eea).withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: TextFormField(
                                      controller: _locationController,
                                      decoration: InputDecoration(
                                        hintText: 'Enter address or location',
                                        hintStyle: TextStyle(color: Color(0xFFa0aec0)),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Color(0xFFe2e8f0), width: 2),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Color(0xFFe2e8f0), width: 2),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Color(0xFF667eea), width: 2),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        suffixIcon: _locationController.text.isNotEmpty
                                            ? IconButton(
                                          icon: Icon(Icons.clear, color: Colors.grey),
                                          onPressed: () {
                                            setState(() {
                                              _locationController.clear();
                                              editedPost['location'] = '';
                                            });
                                          },
                                        )
                                            : null,
                                      ),
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Color(0xFF2d3748),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'This field is required';
                                        }
                                        return null;
                                      },
                                      onChanged: (value) {
                                        setState(() {
                                          editedPost['location'] = value;
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    child: Row(
                                      children: [
                                        // Use Current Location Button
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: _isGettingLocation ? null : _useCurrentLocation,
                                            child: Container(
                                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              decoration: BoxDecoration(
                                                color: _isGettingLocation
                                                    ? Colors.grey[200]
                                                    : Color(0xFF667eea).withOpacity(0.1),
                                                border: Border.all(
                                                  color: _isGettingLocation
                                                      ? Colors.grey[300]!
                                                      : Color(0xFF667eea).withOpacity(0.3),
                                                  width: 2,
                                                ),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  if (_isGettingLocation) ...[
                                                    SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
                                                      ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Detecting...',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF667eea),
                                                      ),
                                                    ),
                                                  ] else ...[
                                                    Icon(
                                                      Icons.my_location,
                                                      size: 18,
                                                      color: Color(0xFF667eea),
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      'Current',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF667eea),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        // Pick Location from Map Button
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () async {
                                              final selectedLocation = await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => LocationPickerScreen(
                                                    initialAddress: editedPost['location'],
                                                  ),
                                                ),
                                              );
                                              
                                              if (selectedLocation != null) {
                                                setState(() {
                                                  editedPost['location'] = selectedLocation['address'];
                                                  _locationController.text = selectedLocation['address'];
                                                });
                                              }
                                            },
                                            child: Container(
                                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              decoration: BoxDecoration(
                                                color: Color(0xFF764ba2).withOpacity(0.1),
                                                border: Border.all(
                                                  color: Color(0xFF764ba2).withOpacity(0.3),
                                                  width: 2,
                                                ),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.map,
                                                    size: 18,
                                                    color: Color(0xFF764ba2),
                                                  ),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    'Pick on Map',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF764ba2),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 20),

                            // Notes
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Additional Notes',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2d3748),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  TextFormField(
                                    initialValue: editedPost['notes'],
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      hintText: 'Any additional details (optional)',
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
                                        borderSide: BorderSide(
                                          color: Color(0xFF667eea),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        editedPost['notes'] = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 20),

                            // Image Selection
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Item Photo',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2d3748),
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  if (_image != null)
                                    Container(
                                      width: double.infinity,
                                      height: 200,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: FileImage(_image!),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    )
                                  else if (widget.post['imageUrl'] != null && widget.post['imageUrl'] != '')
                                    Container(
                                      width: double.infinity,
                                      height: 200,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: NetworkImage(widget.post['imageUrl']),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: double.infinity,
                                      height: 200,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey[300]!),
                                      ),
                                      child: Icon(
                                        Icons.image,
                                        size: 60,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _selectImage,
                                          icon: Icon(Icons.photo_library),
                                          label: Text('Gallery'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey[200],
                                            foregroundColor: Colors.grey[700],
                                            padding: EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _captureImage,
                                          icon: Icon(Icons.camera_alt),
                                          label: Text('Camera'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Color(0xFF667eea),
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 20),

                            // Submit Button
                            Container(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _updatePost,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF667eea),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isSubmitting
                                    ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Text(
                                        'Update Post',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}