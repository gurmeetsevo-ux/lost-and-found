import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String title;
  final String category;
  final String description;
  final String date;
  final String time;
  final Location location;
  final String status;
  final String notes;
  final String type;
  final String? imageUrl;
  final String userId;
  final String userEmail;
  final String userName;
  final bool isActive;
  final int claims;
  final bool showOnMap;
  final String mapVisibility;

  Post({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.date,
    required this.time,
    required this.location,
    required this.status,
    required this.notes,
    required this.type,
    required this.imageUrl,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.isActive,
    required this.claims,
    required this.showOnMap,
    required this.mapVisibility,
  });

  factory Post.fromMap(Map<String, dynamic> map, String id) {
    return Post(
      id: id,
      title: map['title'] ?? '',
      category: map['category'] ?? 'Other',
      description: map['description'] ?? '',
      date: map['date'] ?? '',
      time: map['time'] ?? '',
      location: Location.fromMap(map['location']),
      status: map['status'] ?? '',
      notes: map['notes'] ?? '',
      type: map['type'] ?? 'lost',
      imageUrl: map['imageUrl'],
      userId: map['userId'] ?? 'anonymous',
      userEmail: map['userEmail'] ?? 'anonymous@example.com',
      userName: map['userName'] ?? 'Anonymous User',
      isActive: map['isActive'] ?? true,
      claims: map['claims'] ?? 0,
      showOnMap: map['showOnMap'] ?? true,
      mapVisibility: map['mapVisibility'] ?? 'public',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'description': description,
      'date': date,
      'time': time,
      'location': location.toMap(),
      'status': status,
      'notes': notes,
      'type': type,
      'imageUrl': imageUrl,
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'isActive': isActive,
      'claims': claims,
      'showOnMap': showOnMap,
      'mapVisibility': mapVisibility,
    };
  }
}

class Location {
  final String address;
  final Coordinates coordinates;
  final double? accuracy;
  final DateTime? timestamp;

  Location({
    required this.address,
    required this.coordinates,
    required this.accuracy,
    required this.timestamp,
  });

  factory Location.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return Location(
        address: '',
        coordinates: Coordinates(latitude: 0.0, longitude: 0.0),
        accuracy: 0.0,
        timestamp: DateTime.now(),
      );
    }

    DateTime? timestamp;
    if (map['timestamp'] is Timestamp) {
      timestamp = (map['timestamp'] as Timestamp).toDate();
    } else if (map['timestamp'] is String) {
      timestamp = DateTime.parse(map['timestamp']);
    }

    return Location(
      address: map['address'] ?? '',
      coordinates: Coordinates.fromMap(map['coordinates']),
      accuracy: map['accuracy']?.toDouble(),
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'coordinates': coordinates.toMap(),
      'accuracy': accuracy,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : null,
    };
  }
}

class Coordinates {
  final double latitude;
  final double longitude;

  Coordinates({
    required this.latitude,
    required this.longitude,
  });

  factory Coordinates.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return Coordinates(latitude: 0.0, longitude: 0.0);
    }

    return Coordinates(
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}