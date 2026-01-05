import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'post_detail_screen.dart';
import 'services/post_service.dart'; // Add this import

class MapScreen extends StatefulWidget {
  final VoidCallback onNavigateBack;
  final Widget bottomNav;
  final Function(Map<String, dynamic>) onItemSelected;
  final VoidCallback? onRefresh;

  const MapScreen({
    Key? key,
    required this.onNavigateBack,
    required this.bottomNav,
    required this.onItemSelected,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final CustomInfoWindowController _customInfoWindowController = CustomInfoWindowController();

  Set<Marker> _markers = {};
  List<Map<String, dynamic>> _mapItems = [];
  Position? _currentPosition;
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'lost', 'found'
  
  // Flag to track if screen needs refresh
  bool _needsRefresh = false;

  // Default map position centered on Punjab, India
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(30.8708161, 75.8037457), // Center of Punjab, India (Ludhiana)
    zoom: 10,
  );

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void dispose() {
    _customInfoWindowController.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    await _getCurrentLocation();
    await _fetchMapItems();
    await _createMarkers();
  }

  // 🎯 GET USER'S CURRENT LOCATION
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return;
        }
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print('📍 Current position: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
    } catch (e) {
      print('❌ Error getting current location: $e');
    }
  }

  // 🎯 FETCH ALL ITEMS WITH LOCATION DATA FROM FIRESTORE
  Future<void> _fetchMapItems() async {
    try {
      print('🗺️ Fetching map items from Firestore...');
      
      // Use the PostService to fetch posts
      List<Map<String, dynamic>> items = await PostService.fetchPostsForMap();

      setState(() {
        _mapItems = items;
        _isLoading = false;
      });

      print('🗺️ Loaded ${items.length} items for map display');
      
      // Recreate markers after fetching new data
      await _createMarkers();
    } catch (e) {
      print('❌ Error fetching map items: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 🔄 REFRESH MAP DATA
  Future<void> _refreshMapData() async {
    setState(() {
      _isLoading = true;
    });
    await _fetchMapItems();
  }

  // 🎯 CREATE CUSTOM MARKERS FOR DIFFERENT ITEM TYPES
  Future<void> _createMarkers() async {
    Set<Marker> markers = {};

    for (Map<String, dynamic> item in _mapItems) {
      // Apply filter
      if (_selectedFilter != 'all' && item['type'] != _selectedFilter) {
        continue;
      }

      final coordinates = item['location']['coordinates'];
      final LatLng position = LatLng(
        (coordinates['latitude'] is int) ? coordinates['latitude'].toDouble() : coordinates['latitude'],
        (coordinates['longitude'] is int) ? coordinates['longitude'].toDouble() : coordinates['longitude'],
      );

      // Create custom marker based on item type
      BitmapDescriptor markerIcon = await _createCustomMarker(item);

      markers.add(
        Marker(
          markerId: MarkerId(item['id']),
          position: position,
          icon: markerIcon,
          onTap: () => _onMarkerTapped(item),
          infoWindow: InfoWindow(
            title: item['type']?.toString().toUpperCase() ?? 'ITEM', // Updated to show "LOST" or "FOUND"
            snippet: item['title'] ?? 'Unknown Item', // Updated to show item title as snippet
          ),
        ),
      );
    }

    // Add current location marker if available
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: await _createCurrentLocationMarker(),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Current Position',
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });

    print('🗺️ Created ${markers.length} markers on map');
  }

  // 🎯 CREATE CUSTOM MARKER ICONS - Modernized pins for Lost/Found
  Future<BitmapDescriptor> _createCustomMarker(Map<String, dynamic> item) async {
    final isLost = item['type']?.toString().toLowerCase() == 'lost';
    final Color markerColor = isLost ? Colors.red : Colors.green;
    
    return await _createModernMarker(markerColor, isLost ? 'L' : 'F');
  }
  
  // Create a modern pin marker with a letter (L/F) and color (Bigger size)
  Future<BitmapDescriptor> _createModernMarker(Color color, String letter) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 150.0; // Size of the marker

    // Draw pin shape
    final Paint pinPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Pin top circle (positioned at the top third of the canvas)
    final Offset circleCenter = Offset(size / 2, size / 3);
    final double circleRadius = size / 3;
    
    canvas.drawCircle(circleCenter, circleRadius, pinPaint);
    canvas.drawCircle(circleCenter, circleRadius, borderPaint);
    
    // Pin bottom triangle
    final Path triangle = Path()
      ..moveTo(size / 2, size / 3 * 2)
      ..lineTo(size / 2 - size / 4, size - size / 6)
      ..lineTo(size / 2 + size / 4, size - size / 6)
      ..close();
    
    canvas.drawPath(triangle, pinPaint);
    canvas.drawPath(triangle, borderPaint);
    
    // Draw letter (L for Lost, F for Found) - Centered in the circle
    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: letter,
      style: const TextStyle(
        fontFamily: 'Arial',
        fontSize: 32,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    
    // Position text at the center of the circle
    final Offset textPosition = Offset(
      circleCenter.dx - textPainter.width / 2,  // Center horizontally
      circleCenter.dy - textPainter.height / 2,  // Center vertically
    );
    
    textPainter.paint(canvas, textPosition);

    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image image = await picture.toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }
  
  // Create marker for current location with "You" text (Bigger size)
  Future<BitmapDescriptor> _createCurrentLocationMarker() async {
    return await _createModernMarkerWithText(Colors.blue, 'You');
  }
  
  // Modified version for "You" marker with text instead of single letter
  Future<BitmapDescriptor> _createModernMarkerWithText(Color color, String text) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 80.0; // Size of the marker

    // Draw pin shape
    final Paint pinPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Pin top circle (positioned at the top third of the canvas)
    final Offset circleCenter = Offset(size / 2, size / 3);
    final double circleRadius = size / 3;
    
    canvas.drawCircle(circleCenter, circleRadius, pinPaint);
    canvas.drawCircle(circleCenter, circleRadius, borderPaint);
    
    // Pin bottom triangle
    final Path triangle = Path()
      ..moveTo(size / 2, size / 3 * 2)
      ..lineTo(size / 2 - size / 4, size - size / 6)
      ..lineTo(size / 2 + size / 4, size - size / 6)
      ..close();
    
    canvas.drawPath(triangle, pinPaint);
    canvas.drawPath(triangle, borderPaint);
    
    // Draw text - Centered in the circle
    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: text,
      style: const TextStyle(
        fontFamily: 'Arial',
        fontSize: 16,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    
    // Position text at the center of the circle
    final Offset textPosition = Offset(
      circleCenter.dx - textPainter.width / 2,  // Center horizontally
      circleCenter.dy - textPainter.height / 2,  // Center vertically
    );
    
    textPainter.paint(canvas, textPosition);

    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image image = await picture.toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  // Show all marker info windows by default
  void _showAllMarkerInfoWindows() {
    // This would normally show all info windows, but Google Maps doesn't support
    // showing multiple info windows at once. Instead, we'll just ensure markers are created properly.
    print('Markers created with info windows ready to show on tap');
  }

  // 🎯 HANDLE MARKER TAP - OPEN POST DETAIL SCREEN
  void _onMarkerTapped(Map<String, dynamic> item) {
    // Hide any open info window
    _customInfoWindowController.hideInfoWindow!();
    
    // Navigate to PostDetailScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(post: item),
      ),
    );
  }

  // 🎯 FILTER METHODS
  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _createMarkers();
    print('🔍 Applied filter: $filter');
  }
  
  // 🔄 PUBLIC METHOD TO REFRESH THE MAP
  void refreshMap() {
    _refreshMapData();
  }
  
  // 🔄 METHOD TO FORCE REFRESH WITH IMMEDIATE DATA FETCH
  Future<void> forceRefresh() async {
    await _refreshMapData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: _currentPosition != null
                ? CameraPosition(
              target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              zoom: 14,
            )
                : _initialPosition,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              _customInfoWindowController.googleMapController = controller;
            },

            onTap: (LatLng position) {
              _customInfoWindowController.hideInfoWindow!();
            },
            onCameraMove: (CameraPosition position) {
              _customInfoWindowController.onCameraMove!();
            },
          ),

          // Custom Info Windows
          CustomInfoWindow(
            controller: _customInfoWindowController,
            height: 200,
            width: 280,
            offset: 50,
          ),

          // Header
          _buildHeader(),

          // Filter Buttons
          _buildFilterButtons(),

          // Loading Indicator
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Theme.of(context).primaryColor),
                    const SizedBox(height: 16),
                    Text(
                      'Loading map items...',
                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // My Location Button
          Positioned(
            bottom: 100,
            right: 20,
            child: FloatingActionButton(
              onPressed: _goToCurrentLocation,
              backgroundColor: Theme.of(context).cardTheme.color,
              child: Icon(Icons.my_location, color: Theme.of(context).primaryColor),
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.bottomNav,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.9),
            Theme.of(context).primaryColor.withOpacity(0.0),
          ],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onNavigateBack,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color?.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.chevron_left, color: Theme.of(context).primaryColor, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color?.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.map, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lost & Found Map',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_mapItems.length} items',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
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

  Widget _buildFilterButtons() {
    return Positioned(
      top: 140,
      left: 20,
      right: 20,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildFilterButton('all', 'All', Icons.all_inclusive, Colors.grey),
            _buildFilterButton('lost', 'Lost', Icons.search, Colors.red),
            _buildFilterButton('found', 'Found', Icons.check_circle, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String filter, String label, IconData icon, Color color) {
    final isSelected = _selectedFilter == filter;

    return Expanded(
      child: GestureDetector(
        onTap: () => _applyFilter(filter),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? color : Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? color : Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToCurrentLocation() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 16,
          ),
        ),
      );
    }
  }
}