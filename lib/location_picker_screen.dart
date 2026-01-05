import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;

  const LocationPickerScreen({
    Key? key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  }) : super(key: key);

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String _selectedAddress = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLatitude != null && widget.initialLongitude != null
        ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
        : null;
    _selectedAddress = widget.initialAddress ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          if (_selectedLocation != null)
            TextButton(
              onPressed: _selectedLocation != null ? _confirmSelection : null,
              child: Text(
                'Confirm',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation ??
                  const LatLng(30.8708161, 75.8037457), // Default to Punjab, India
              zoom: _selectedLocation != null ? 15 : 10,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              setState(() {
                _isLoading = false;
              });
            },
            onTap: _handleMapTap,
            markers: _selectedLocation != null
                ? {
                    Marker(
                      markerId: const MarkerId('selected_location'),
                      position: _selectedLocation!,
                      infoWindow: InfoWindow(
                        title: 'Selected Location',
                        snippet: _selectedAddress.isEmpty ? 'Tap to select' : _selectedAddress,
                      ),
                    ),
                  }
                : {},
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
          ),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
              ),
            ),
          if (_selectedLocation != null)
            Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.location_on,
                  color: Theme.of(context).primaryColor,
                  size: 30,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleMapTap(LatLng tappedLocation) async {
    setState(() {
      _selectedLocation = tappedLocation;
      _selectedAddress = 'Getting address...';
    });

    // Get address from coordinates
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        tappedLocation.latitude,
        tappedLocation.longitude,
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

        setState(() {
          _selectedAddress = address;
        });
      } else {
        setState(() {
          _selectedAddress = 'Address not found';
        });
      }
    } catch (e) {
      setState(() {
        _selectedAddress = 'Unable to get address';
      });
    }
  }

  void _confirmSelection() {
    if (_selectedLocation != null) {
      Navigator.of(context).pop({
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'address': _selectedAddress,
      });
    }
  }
}