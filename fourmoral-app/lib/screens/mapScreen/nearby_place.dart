import 'package:google_maps_flutter/google_maps_flutter.dart';

class NearbyPlace {
  final String id;
  final String name;
  final LatLng location;
  final double distance;
  final String? imageUrl;
  final String type; // 'post', 'user', or 'place'

  NearbyPlace({
    required this.id,
    required this.name,
    required this.location,
    required this.distance,
    this.imageUrl,
    required this.type,
  });
}