import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

class MapScreen extends StatefulWidget {
  final VoidCallback onNavigateBack;
  final Widget bottomNav;
  final Function(Map<String, dynamic>) onItemSelected;

  const MapScreen({
    Key? key,
    required this.onNavigateBack,
    required this.bottomNav,
    required this.onItemSelected,
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

  // Default map position (you can change this to your preferred location)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(37.7749, -122.4194), // San Francisco
    zoom: 12,
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

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('showOnMap', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> items = [];

      for (QueryDocumentSnapshot doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // Validate that item has location coordinates
        if (data['location'] != null &&
            data['location']['coordinates'] != null &&
            data['location']['coordinates']['latitude'] != null &&
            data['location']['coordinates']['longitude'] != null) {
          items.add(data);
          print('✅ Added item to map: ${data['title']} at ${data['location']['coordinates']['latitude']}, ${data['location']['coordinates']['longitude']}');
        } else {
          print('❌ Skipped item without coordinates: ${data['title']}');
        }
      }

      setState(() {
        _mapItems = items;
        _isLoading = false;
      });

      print('🗺️ Loaded ${items.length} items for map display');
    } catch (e) {
      print('❌ Error fetching map items: $e');
      setState(() {
        _isLoading = false;
      });
    }
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
        coordinates['latitude'].toDouble(),
        coordinates['longitude'].toDouble(),
      );

      // Create custom marker based on item type
      BitmapDescriptor markerIcon = await _createCustomMarker(item);

      markers.add(
        Marker(
          markerId: MarkerId(item['id']),
          position: position,
          icon: markerIcon,
          onTap: () => _onMarkerTapped(item, position),
          infoWindow: InfoWindow(
            title: item['title'] ?? 'Unknown Item',
            snippet: '${item['type']?.toString().toUpperCase()} • ${item['category']}',
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

  // 🎯 CREATE CUSTOM MARKER ICONS
  Future<BitmapDescriptor> _createCustomMarker(Map<String, dynamic> item) async {
    final isLost = item['type']?.toString().toLowerCase() == 'lost';
    final Color markerColor = isLost ? Colors.red : Colors.green;
    final IconData iconData = isLost ? Icons.search : Icons.check_circle;

    return await _createMarkerFromIcon(iconData, markerColor);
  }

  Future<BitmapDescriptor> _createCurrentLocationMarker() async {
    return await _createMarkerFromIcon(Icons.my_location, Colors.blue);
  }

  Future<BitmapDescriptor> _createMarkerFromIcon(IconData icon, Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 100.0;

    // Draw marker background circle
    final Paint backgroundPaint = Paint()..color = color;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, backgroundPaint);

    // Draw white border
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 3, borderPaint);

    // Draw icon
    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontFamily: icon.fontFamily,
        fontSize: 40,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image image = await picture.toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  // 🎯 HANDLE MARKER TAP - SHOW CUSTOM INFO WINDOW
  void _onMarkerTapped(Map<String, dynamic> item, LatLng position) {
    _customInfoWindowController.addInfoWindow!(
      _buildCustomInfoWindow(item),
      position,
    );
  }

  // 🎯 CUSTOM INFO WINDOW DESIGN
  Widget _buildCustomInfoWindow(Map<String, dynamic> item) {
    final isLost = item['type']?.toString().toLowerCase() == 'lost';

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with color coding
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isLost ? Colors.red[600] : Colors.green[600],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  isLost ? Icons.search : Icons.check_circle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item['title'] ?? 'Unknown Item',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category and Type badges
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item['category'] ?? 'Other',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item['type']?.toString().toUpperCase() ?? 'UNKNOWN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isLost ? Colors.red[600] : Colors.green[600],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Description
                if (item['description']?.toString().isNotEmpty == true)
                  Text(
                    item['description'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                const SizedBox(height: 8),

                // Location
                if (item['location']?['address']?.toString().isNotEmpty == true)
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item['location']['address'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 12),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _customInfoWindowController.hideInfoWindow!();
                      widget.onItemSelected(item);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLost ? Colors.red[600] : Colors.green[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      isLost ? 'I Found This!' : 'This Is Mine!',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Loading map items...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
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
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Color(0xFF667eea)),
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
            const Color(0xFF667eea).withOpacity(0.9),
            const Color(0xFF667eea).withOpacity(0.0),
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
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.chevron_left, color: Color(0xFF667eea), size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.map, color: Color(0xFF667eea)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Lost & Found Map',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF667eea),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_mapItems.length} items',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF667eea),
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
          color: Colors.white,
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
                color: isSelected ? color : Colors.grey[600],
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? color : Colors.grey[600],
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
