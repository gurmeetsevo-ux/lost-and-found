// lib/map_clustering.dart
import 'package:google_maps_cluster_manager/google_maps_cluster_manager.dart';

class MapItem extends ClusterItem {
  final String id;
  final String title;
  final String type;
  final Map<String, dynamic> data;
  final LatLng position;

  MapItem({
    required this.id,
    required this.title,
    required this.type,
    required this.data,
    required this.position,
  });

  @override
  LatLng get location => position;
}

class OptimizedMapScreen extends StatefulWidget {
  // ... existing code

  @override
  State<OptimizedMapScreen> createState() => _OptimizedMapScreenState();
}

class _OptimizedMapScreenState extends State<OptimizedMapScreen> {
  ClusterManager? _clusterManager;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initializeClusterManager();
  }

  void _initializeClusterManager() {
    _clusterManager = ClusterManager<MapItem>(
      _mapItems.map((item) => MapItem(
        id: item['id'],
        title: item['title'],
        type: item['type'],
        data: item,
        position: LatLng(
          item['location']['coordinates']['latitude'],
          item['location']['coordinates']['longitude'],
        ),
      )).toList(),
      _updateMarkers,
      markerBuilder: _markerBuilder,
      levels: [1, 4.25, 6.75, 8.25, 11.5, 14.5, 16.0, 16.5, 20.0],
    );
  }

  void _updateMarkers(Set<Marker> markers) {
    setState(() {
      _markers = markers;
    });
  }

  Future<Marker> _markerBuilder(Cluster<MapItem> cluster) async {
    return Marker(
      markerId: MarkerId(cluster.getId()),
      position: cluster.location,
      icon: await _getClusterMarker(cluster),
      onTap: () => _onClusterTapped(cluster),
    );
  }
}
