import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'services/algolia_manual_service.dart';
import 'location_picker_screen.dart';


class AddPostScreen extends StatefulWidget {
  final String postType;
  final Function(String) setPostType;
  final Function(Map<String, dynamic>) onAddPost;
  final VoidCallback onBack;
  final Map<String, dynamic>? user;

  const AddPostScreen({
    Key? key,
    required this.postType,
    required this.setPostType,
    required this.onAddPost,
    required this.onBack,
    this.user,
  }) : super(key: key);

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen>
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

  // Method to fetch user's anonymous mode setting from Firebase
  Future<bool> _getUserAnonymousMode() async {
    try {
      if (widget.user != null && widget.user!['uid'] != null) {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user!['uid'])
            .get();

        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return data['isAnonymous'] ?? false;
        }
      }
    } catch (e) {
      print('Error fetching user anonymous mode: $e');
    }
    return false; // Default to false if there's an error
  }

  // Form fields
  Map<String, dynamic> newPost = {
    'title': '',
    'category': 'Electronics',
    'description': '',
    'date': '',
    'time': '',
    'location': '',
    'status': 'have',
    'notes': '',
  };

  @override
  void initState() {
    super.initState();
    newPost['date'] = DateTime.now().toIso8601String().split('T')[0];

    // Initialize location controller
    _locationController.text = newPost['location'];

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
        if (place.country?.isNotEmpty == true) addressParts.add(place.country!);

        String address = addressParts.join(', ');

        // Fallback if address is too short
        if (address.length < 10) {
          address = '${place.locality ?? 'Unknown Area'}, ${place.country ?? 'Unknown Country'}';
        }

        print('📍 Detected Address: $address');

        // 🎯 AUTOMATICALLY FILL THE TEXT FIELD
        setState(() {
          _locationController.text = address; // Fill the text field
          newPost['location'] = address;      // Update the form data
          newPost['coordinates'] = null;      // Clear any manually set coordinates
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.location_on, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location automatically filled: ${address.length > 50 ? address.substring(0, 50) + '...' : address}',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        _showLocationError('Could not get address for your location. Please enter manually.');
      }

    } catch (e) {
      print('❌ Location Error: $e');

      String errorMessage = 'Failed to get location';
      if (e.toString().contains('timeout')) {
        errorMessage = 'Location request timed out. Please try again.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection.';
      }

      _showLocationError(errorMessage);
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  // Enhanced location capture method
  Future<Map<String, dynamic>?> _captureEnhancedLocationData() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      // Don't clear coordinates if they were set from map picker
      // Only clear if we're intentionally getting current location
      // setState(() {
      //   newPost['coordinates'] = null;
      // });
      
      // Get current position with high accuracy
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );

      print('📍 GPS Position: ${position.latitude}, ${position.longitude}');

      // Get human-readable address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Build address string
        List<String> addressParts = [];
        if (place.street?.isNotEmpty == true) addressParts.add(place.street!);
        if (place.locality?.isNotEmpty == true) addressParts.add(place.locality!);
        if (place.administrativeArea?.isNotEmpty == true) addressParts.add(place.administrativeArea!);
        if (place.country?.isNotEmpty == true) addressParts.add(place.country!);

        String address = addressParts.join(', ');

        // Return enhanced location data
        return {
          'address': address,
          'coordinates': {
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
          'accuracy': position.accuracy,
          'timestamp': FieldValue.serverTimestamp(),
        };
      }
    } catch (e) {
      print('❌ Error capturing enhanced location: $e');
      _showLocationError('Failed to get precise location. Please try again.');
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
    return null;
  }

  void _showLocationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  // New method to open location picker
  Future<void> _openLocationPicker() async {
    try {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LocationPickerScreen(
            initialLatitude: null,
            initialLongitude: null,
            initialAddress: _locationController.text,
          ),
        ),
      );

      if (result != null && result is Map<String, dynamic>) {
        setState(() {
          _locationController.text = result['address'];
          newPost['location'] = result['address'];
          // Store coordinates separately for later use
          newPost['coordinates'] = {
            'latitude': result['latitude'],
            'longitude': result['longitude'],
          };
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.location_on, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location selected: ${result['address'].length > 50 ? result['address'].substring(0, 50) + '...' : result['address']}',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('❌ Location Picker Error: $e');
      _showLocationError('Failed to open location picker. Please try again.');
    }
  }

  Future<void> _choosePhoto() async {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.photo_library, color: Color(0xFF667eea)),
                title: Text('Photo Library'),
                onTap: () {
                  _getImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_camera, color: Color(0xFF667eea)),
                title: Text('Camera'),
                onTap: () {
                  _getImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getImage(ImageSource source) async {
    final picked = await picker.pickImage(source: source);
    if (picked != null) {
      setState(() => _image = File(picked.path));
    }
  }

  Future<String?> _uploadImage() async {
    if (_image == null) return null;

    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = FirebaseStorage.instance
          .ref()
          .child('post_images/$fileName.jpg');

      await ref.putFile(_image!);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  // Future<void> _savePostToFirestore() async {
  //   if (!_formKey.currentState!.validate()) return;
  //
  //   setState(() {
  //     _isSubmitting = true;
  //   });
  //
  //   try {
  //     // Upload image first (if exists)
  //     String? imageUrl;
  //     if (_image != null) {
  //       imageUrl = await _uploadImage();
  //     }
  //
  //     // Prepare post data
  //     Map<String, dynamic> postData = {
  //       'title': newPost['title'],
  //       'category': newPost['category'],
  //       'description': newPost['description'],
  //       'date': newPost['date'],
  //       'time': newPost['time'],
  //       'location': newPost['location'],
  //       'status': newPost['status'],
  //       'notes': newPost['notes'] ?? '',
  //       'type': widget.postType,
  //       'imageUrl': imageUrl,
  //       'createdAt': FieldValue.serverTimestamp(),
  //       'updatedAt': FieldValue.serverTimestamp(),
  //       'userId': widget.user?['uid'] ?? 'anonymous',
  //       'userEmail': widget.user?['email'] ?? 'anonymous@example.com',
  //       'userName': widget.user?['name'] ?? 'Anonymous User',
  //       'isActive': true,
  //       'claims': 0,
  //     };
  //
  //     // Save to both Firestore and Algolia using manual sync
  //     String docId = await AlgoliaManualService.addPost(postData);
  //
  //     // Success feedback
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('${widget.postType == 'lost' ? 'Lost' : 'Found'} item posted with Algolia search!'),
  //           backgroundColor: Colors.green,
  //           duration: Duration(seconds: 3),
  //         ),
  //       );
  //     }
  //
  //     // Call callback and navigate
  //     postData['id'] = docId;
  //     widget.onAddPost(postData);
  //     widget.onBack();
  //
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Error posting item: ${e.toString()}'),
  //           backgroundColor: Colors.red,
  //           duration: Duration(seconds: 3),
  //         ),
  //       );
  //     }
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isSubmitting = false;
  //       });
  //     }
  //   }
  // }

  Future<void> _savePostToFirestore() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 🎯 CAPTURE ENHANCED LOCATION DATA
      Map<String, dynamic>? locationData;
      
      // Check if the location was selected from the map picker
      if (newPost['coordinates'] != null) {
        // Use the coordinates selected from the map picker
        locationData = {
          'address': _locationController.text,
          'coordinates': newPost['coordinates'],
          'accuracy': 10.0, // Set to a reasonable default for manually selected locations
          'timestamp': FieldValue.serverTimestamp(),
        };
      } else {
        // Use current location if no map picker coordinates available
        locationData = await _captureEnhancedLocationData();
        if (locationData == null) {
          locationData = {
            'address': _locationController.text,
            'coordinates': null,
            'accuracy': null,
            'timestamp': FieldValue.serverTimestamp(),
          };
        }
      }
      
      // Ensure coordinates are properly formatted for map display
      if (locationData != null && locationData['coordinates'] != null) {
        // Make sure coordinates are in the expected format: {latitude: ..., longitude: ...}
        if (locationData['coordinates'] is Map<String, dynamic>) {
          // Already in correct format
        } else if (locationData['coordinates'] is Map) {
          // Convert to String keys format if needed
          Map originalCoords = locationData['coordinates'];
          locationData['coordinates'] = {
            'latitude': originalCoords['latitude'],
            'longitude': originalCoords['longitude'],
          };
        }
      }

      String? imageUrl;
      if (_image != null) {
        imageUrl = await _uploadImage();
      }

      // Check user's anonymous mode setting from Firebase
      bool userAnonymousMode = await _getUserAnonymousMode();
      
      // Prepare enhanced post data
      Map<String, dynamic> postData = {
        'title': newPost['title'],
        'category': newPost['category'],
        'description': newPost['description'],
        'date': newPost['date'],
        'time': newPost['time'],

        // 🎯 ENHANCED LOCATION DATA
        'location': locationData ?? {
          'address': _locationController.text,
          'coordinates': null, // No GPS data available
          'accuracy': null,
          'timestamp': FieldValue.serverTimestamp(),
        },

        'status': newPost['status'],
        'notes': newPost['notes'] ?? '',
        'type': widget.postType,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'userId': widget.user?['uid'] ?? 'anonymous',
        'userEmail': widget.user?['email'] ?? 'anonymous@example.com',
        'userName': userAnonymousMode ? 'Anonymous User' : (widget.user?['name'] ?? 'User'),
        'isActive': true,
        'claims': 0,

        // 🎯 NEW: Map visibility settings
        'showOnMap': true, // Default to show on map
        'mapVisibility': 'public', // Default visibility
      };

      String docId = await AlgoliaManualService.addPost(postData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.postType == 'lost' ? 'Lost' : 'Found'} item posted and will appear on map!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      postData['id'] = docId;
      widget.onAddPost(postData);
      widget.onBack();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error posting item: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
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

  bool _isFormValid() {
    return newPost['title']?.isNotEmpty == true &&
        newPost['description']?.isNotEmpty == true &&
        newPost['location']?.isNotEmpty == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.zero,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _slideController,
                    child: _buildFormCard(),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onBack,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.chevron_left,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.postType == 'lost' ? 'Report Lost Item' : 'Report Found Item',
              style: const TextStyle(
                fontSize: 20,
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
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 60,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPostTypeSelector(),
              const SizedBox(height: 24),
              _buildPhotoUpload(),
              const SizedBox(height: 20),
              _buildFormSection(
                label: widget.postType == 'lost'
                    ? 'What did you lose?'
                    : 'What did you find?',
                required: true,
                child: _buildTextInput(
                  placeholder: 'e.g., Black wallet, iPhone',
                  value: newPost['title'],
                  onChanged: (v) => setState(() => newPost['title'] = v),
                ),
              ),
              _buildFormSection(
                label: 'Category',
                required: true,
                child: _buildDropdown(),
              ),
              _buildFormSection(
                label: 'Description',
                required: true,
                child: _buildTextarea(
                  placeholder: widget.postType == 'lost'
                      ? 'e.g., Black leather wallet with credit cards'
                      : 'e.g., Black leather wallet with cards inside',
                  value: newPost['description'],
                  onChanged: (v) => setState(() => newPost['description'] = v),
                ),
              ),
              _buildFormSection(
                label: widget.postType == 'lost' ? 'When lost?' : 'When found?',
                required: true,
                child: _buildDateTimeInputs(),
              ),
              _buildFormSection(
                label: widget.postType == 'lost' ? 'Where lost?' : 'Where found?',
                required: true,
                child: _buildLocationInput(), // AUTO-FILL LOCATION INPUT
              ),
              if (widget.postType == 'found') ...[
                _buildFormSection(
                  label: 'Item Status',
                  required: false,
                  child: _buildStatusOptions(),
                ),
              ] else ...[
                _buildFormSection(
                  label: 'Additional Notes',
                  required: false,
                  child: _buildTextarea(
                    placeholder: 'Any other details... e.g., Last seen in coffee shop',
                    value: newPost['notes'] ?? '',
                    onChanged: (v) => setState(() => newPost['notes'] = v),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  // 🎯 AUTO-FILL LOCATION INPUT - SINGLE METHOD
  Widget _buildLocationInput() {
    return Column(
      children: [
        // Text field with controller for auto-fill
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
            controller: _locationController, // 🎯 AUTO-FILL CONTROLLER
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
                    newPost['location'] = '';
                    newPost['coordinates'] = null;
                  });
                },
              )
                  : null,
            ),
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF2d3748),
            ),
            // Update form data when user types manually
            onChanged: (value) {
              setState(() {
                newPost['location'] = value;
                // Clear coordinates when user manually edits location
                newPost['coordinates'] = null;
              });
            },
            validator: (v) => v == null || v.isEmpty ? 'This field is required' : null,
          ),
        ),

        SizedBox(height: 10),

        // Buttons for location options
        Row(
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
                        SizedBox(width: 12),
                        Text(
                          'Detecting...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF667eea),
                          ),
                        ),
                      ] else ...[
                        Icon(
                          Icons.my_location,
                          size: 20,
                          color: Color(0xFF667eea),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Current',
                          style: TextStyle(
                            fontSize: 14,
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
                onTap: _isGettingLocation ? null : _openLocationPicker,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isGettingLocation
                        ? Colors.grey[200]
                        : Color(0xFF764ba2).withOpacity(0.1),
                    border: Border.all(
                      color: _isGettingLocation
                          ? Colors.grey[300]!
                          : Color(0xFF764ba2).withOpacity(0.3),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.map,
                        size: 20,
                        color: Color(0xFF764ba2),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Pick on Map',
                        style: TextStyle(
                          fontSize: 14,
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
      ],
    );
  }

  Widget _buildPostTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(child: _buildTypeButton('lost', Icons.search, Colors.red)),
          SizedBox(width: 4),
          Expanded(child: _buildTypeButton('found', Icons.check_circle, Colors.green)),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String type, IconData icon, Color color) {
    final isActive = widget.postType == type;

    return GestureDetector(
      onTap: () => widget.setPostType(type),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive ? [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? Colors.white : Colors.grey[600],
            ),
            SizedBox(width: 8),
            Text(
              '${type.substring(0, 1).toUpperCase()}${type.substring(1)} Item',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoUpload() {
    return GestureDetector(
      onTap: _choosePhoto,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!, width: 2, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey[50],
        ),
        padding: EdgeInsets.all(_image != null ? 0 : 24),
        child: _image != null ? _buildPhotoPreview() : _buildPhotoPlaceholder(),
      ),
    );
  }

  Widget _buildPhotoPreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            _image!,
            width: double.infinity,
            height: 100,
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upload, color: Colors.white, size: 24),
                  SizedBox(height: 6),
                  Text(
                    'Change Photo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Color(0xFF667eea),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.upload, color: Colors.white, size: 32),
        ),
        SizedBox(height: 10),
        Text(
          'Add Photo (Recommended)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2d3748),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Take photo or choose from gallery',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF718096),
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection({
    required String label,
    required bool required,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2d3748),
            ),
            children: required ? [
              TextSpan(
                text: ' *',
                style: TextStyle(color: Color(0xFFef4444)),
              ),
            ] : null,
          ),
        ),
        SizedBox(height: 6),
        child,
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTextInput({
    required String placeholder,
    required String value,
    required Function(String) onChanged,
  }) {
    return Container(
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
        initialValue: value,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: placeholder,
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
        ),
        style: TextStyle(
          fontSize: 15,
          color: Color(0xFF2d3748),
        ),
        validator: (v) => v == null || v.isEmpty ? 'This field is required' : null,
      ),
    );
  }

  Widget _buildTextarea({
    required String placeholder,
    required String value,
    required Function(String) onChanged,
  }) {
    return Container(
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
        initialValue: value,
        onChanged: onChanged,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: placeholder,
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
        ),
        style: TextStyle(
          fontSize: 15,
          color: Color(0xFF2d3748),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
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
      child: DropdownButtonFormField<String>(
        value: newPost['category'],
        items: [
          'Electronics',
          'Wallet/Bag',
          'Keys',
          'Documents',
          'Clothing',
          'Other'
        ].map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
        onChanged: (v) => setState(() => newPost['category'] = v ?? ''),
        decoration: InputDecoration(
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
        ),
        style: TextStyle(
          fontSize: 15,
          color: Color(0xFF2d3748),
        ),
      ),
    );
  }

  Widget _buildDateTimeInputs() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Date',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4a5568),
                ),
              ),
              SizedBox(height: 6),
              _buildDateInput(),
            ],
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Time',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4a5568),
                ),
              ),
              SizedBox(height: 6),
              _buildTimeInput(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateInput() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(newPost['date']!) ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() => newPost['date'] = picked.toIso8601String().split('T')[0]);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Color(0xFFe2e8f0), width: 2),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              newPost['date'] ?? 'Select date',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF2d3748),
              ),
            ),
            Icon(Icons.calendar_today, size: 18, color: Color(0xFF718096)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInput() {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );
        if (picked != null) {
          setState(() => newPost['time'] = picked.format(context));
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Color(0xFFe2e8f0), width: 2),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              newPost['time']?.isNotEmpty == true ? newPost['time'] : 'Select time',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF2d3748),
              ),
            ),
            Icon(Icons.access_time, size: 18, color: Color(0xFF718096)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOptions() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Color(0xFFe2e8f0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          RadioListTile<String>(
            value: 'have',
            groupValue: newPost['status'],
            onChanged: (v) => setState(() => newPost['status'] = v),
            title: Text('I have the item'),
            subtitle: Text('Item is with me'),
            secondary: Icon(Icons.check_circle, color: Colors.green),
          ),
          Divider(height: 1),
          RadioListTile<String>(
            value: 'police',
            groupValue: newPost['status'],
            onChanged: (v) => setState(() => newPost['status'] = v),
            title: Text('Dropped at police station/center'),
            subtitle: Text('Item submitted to authorities'),
            secondary: Icon(Icons.local_police, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final color = widget.postType == 'lost' ? Color(0xFFef4444) : Color(0xFF10b981);

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.postType == 'lost'
              ? [Color(0xFFef4444), Color(0xFFdc2626)]
              : [Color(0xFF10b981), Color(0xFF059669)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (_isFormValid() && !_isSubmitting) ? _savePostToFirestore : null,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: _isSubmitting
                ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
                Text(
                  'POSTING...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            )
                : Text(
              widget.postType == 'lost' ? 'POST LOST ITEM' : 'POST FOUND ITEM',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
