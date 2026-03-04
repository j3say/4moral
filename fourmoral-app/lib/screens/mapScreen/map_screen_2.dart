import 'dart:async';
import 'dart:ui' as ui;
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/models/post_model.dart';
import 'package:fourmoral/models/product_model.dart';
import 'package:fourmoral/models/search_users_model.dart';
import 'package:fourmoral/screens/explorePageScreen/explore_controller.dart';
import 'package:fourmoral/screens/mapScreen/location_share.dart';
import 'package:fourmoral/screens/mapScreen/video_player_widget.dart';
import 'package:fourmoral/screens/postViewScreen/post_view_screen.dart';
import 'package:fourmoral/screens/profileScreen/profile_widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';

class MapScreen3 extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  String? ProfileUrl;
  MapScreen3({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.ProfileUrl,
  });

  @override
  _MapScreen3State createState() => _MapScreen3State();
}

class _MapScreen3State extends State<MapScreen3> {
  final exploreCnt = Get.put(ExploreCnt());

  // Controllers
  late GoogleMapController _mapController;
  final TextEditingController _locationNameController = TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  // Location data
  String activeFilter = 'Nearby';

  LatLng? _currentPosition;
  double? _originLatitude, _originLongitude;
  double? _destLatitude, _destLongitude;
  final MapType _currentMapType = MapType.normal;

  List<SearchModel> filteredUserList = [];
  List<Product> productDataList = [];
  List<Product> filteredProductList = [];

  bool productDataFetched = false;
  final FocusNode _searchFocusNode = FocusNode();
  bool _shouldFocusSearch = false;
  BitmapDescriptor _currentLocationMarker =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
  BitmapDescriptor _destinationMarker = BitmapDescriptor.defaultMarkerWithHue(
    BitmapDescriptor.hueRed,
  );

  // Markers and polylines
  final Map<MarkerId, Marker> _markers = {};
  final Map<PolylineId, Polyline> _polylines = {};
  BitmapDescriptor _defaultMarker = BitmapDescriptor.defaultMarker;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  // UI state
  bool _isLoading = true;
  final LocationAccuracy _locationAccuracy = LocationAccuracy.high;

  // New - Position streaming
  StreamSubscription<Position>? _positionStreamSubscription;
  final searchc = TextEditingController();

  // Constants
  final String _googleApiKey = "AIzaSyCjirUlgby1lfV8BxagtICEBWxlsk1RZlY";
  final PolylinePoints _polylinePoints = PolylinePoints();
  final CollectionReference _savedLocationsCollection = FirebaseFirestore
      .instance
      .collection('saved_locations');

  @override
  void initState() {
    super.initState();
    _initializeMap();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCustomMarkerIcons();
    });
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) => setState(() => _isListening = false),
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              searchc.text = result.recognizedWords;
              onItemChanged(result.recognizedWords);
            });
          },
          listenFor: Duration(seconds: 30),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void onItemChanged(String value) {
    setState(() {
      // Filter users
      filteredUserList =
          searchUserDataList.where((user) {
            return user.uniqueId.toLowerCase().contains(value.toLowerCase()) ||
                user.username.toLowerCase().contains(value.toLowerCase());
          }).toList();

      // Filter hashtags

      // Filter products
      filteredProductList =
          productDataList.where((product) {
            return product.name.toLowerCase().contains(value.toLowerCase()) ||
                (product.description.toLowerCase().contains(
                      value.toLowerCase(),
                    ) ??
                    false) ||
                (product.category?.toLowerCase().contains(
                      value.toLowerCase(),
                    ) ??
                    false);
          }).toList();

      // Sync with post search
      exploreCnt.syncSearchQuery(value);
    });
  }

  Future<void> _initializeMap() async {
    try {
      // Load custom marker icons
      await _loadCustomMarkerIcons();
      await getPostsWithLocation();
      // Check if initial coordinates were provided
      if (widget.initialLatitude != null && widget.initialLongitude != null) {
        _destLatitude = widget.initialLatitude;
        _destLongitude = widget.initialLongitude;
        _addMarker(
          LatLng(_destLatitude!, _destLongitude!),
          "initial_location",
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        );
        await _getCurrentLocation();
      } else {
        await _getCurrentLocation();
      }

      await _loadInitialData();

      // Start listening to position updates
      _startPositionStream();
    } catch (e) {
      debugPrint("Map initialization error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  }

  // New - Load custom marker icons
  Future<void> _loadCustomMarkerIcons() async {
    try {
      final ImageConfiguration imageConfiguration =
          createLocalImageConfiguration(context, size: Size(48, 48));

      // Load custom icons
      final Uint8List currentLocationIconBytes = await getBytesFromAsset(
        'assets/location_icon.png',
        100,
      );
      final Uint8List destinationIconBytes = await getBytesFromAsset(
        'assets/destination_icon.png',
        100,
      );
      final BitmapDescriptor currentLocationIcon = BitmapDescriptor.fromBytes(
        currentLocationIconBytes,
      );

      final BitmapDescriptor destinationIcon = BitmapDescriptor.fromBytes(
        destinationIconBytes,
      );

      // Store them for later use
      _defaultMarker = currentLocationIcon; // or keep default if you prefer

      // You might want to create class variables to store these
      _currentLocationMarker = currentLocationIcon;
      _destinationMarker = destinationIcon;
    } catch (e) {
      debugPrint("Error loading marker icons: $e");
      // Fallback to default markers
      _defaultMarker = BitmapDescriptor.defaultMarker;
      _currentLocationMarker = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueBlue,
      );
      _destinationMarker = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueRed,
      );
    }
  }

  void _expandSheetWithFocus() {
    setState(() {
      _shouldFocusSearch = true;
    });
    _sheetController
        .animateTo(
          0.5, // Your maxChildSize
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        )
        .then((_) {
          if (_shouldFocusSearch) {
            FocusScope.of(context).requestFocus(_searchFocusNode);
          }
        });
  }

  Future<BitmapDescriptor> _getMarkerFromUrl(String? url) async {
    final http.Response response = await http.get(Uri.parse(url!));
    final Uint8List bytes = response.bodyBytes;

    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 100);
    final frame = await codec.getNextFrame();
    final ui.Image image = frame.image;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    const double size = 100.0;
    const double borderWidth = 2.0;

    final Paint paint = Paint();
    final Paint borderPaint =
        Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth;

    final Rect rect = Rect.fromLTWH(0, 0, size, size);
    final RRect rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size / 2),
    );

    // Clip the canvas to a circle
    canvas.clipRRect(rrect);

    // Draw image
    paint.isAntiAlias = true;
    canvas.drawImage(image, Offset.zero, paint);

    // Draw border (after restoring from clip)
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      (size / 2) - (borderWidth / 2),
      borderPaint,
    );

    final ui.Image finalImage = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final ByteData? byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final Uint8List resizedBytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(resizedBytes);
  }

  // Enhanced - Get current location with permission handling
  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showPermissionDeniedDialog();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showPermissionDeniedForeverDialog();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: _locationAccuracy,
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      if (widget.ProfileUrl != '') {
        final icon = await _getMarkerFromUrl(widget.ProfileUrl);
        _addMarker(_currentPosition!, "current_location", icon);
      } else {
        _addMarker(
          _currentPosition!,
          "current_location",
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        );
      }

      // Move camera to current location
      _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentPosition!, zoom: 15),
        ),
      );
    } catch (e) {
      debugPrint("Location error: $e");
      _showErrorSnackBar("Could not get current location");
    }
  }

  // New - Position streaming for live updates
  void _startPositionStream() {
    try {
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) {
        final newPosition = LatLng(position.latitude, position.longitude);

        setState(() async {
          _currentPosition = newPosition;

          // Update current location marker
          if (widget.ProfileUrl != '') {
            final icon = await _getMarkerFromUrl(widget.ProfileUrl);
            _addMarker(newPosition, "current_location", icon);
          } else {
            _addMarker(
              newPosition,
              "current_location",
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            );
          }
        });

        // If route is being shown, recalculate it
        if (_originLatitude != null &&
            _destLatitude != null &&
            _originLatitude == position.latitude &&
            _originLongitude == position.longitude) {
          _calculateRoute();
        }
      });
    } catch (e) {
      debugPrint("Position stream error: $e");
    }
  }

  // Enhanced - Load initial data
  Future<void> _loadInitialData() async {
    try {
      await _loadSavedLocations();
      // Other data loading operations can be added here
    } catch (e) {
      debugPrint("Error loading initial data: $e");
    }
  }

  Future<void> getPostsWithLocation() async {
    try {
      final postsRef = FirebaseFirestore.instance.collection('Posts');
      final Timestamp twentyFourHoursAgo = Timestamp.fromDate(
        DateTime.now().subtract(Duration(hours: 24)),
      );
      QuerySnapshot querySnapshot =
          await postsRef
              .where('hasLocation', isEqualTo: true)
              .where('createdAt', isGreaterThan: twentyFourHoursAgo)
              .get();

      for (var doc in querySnapshot.docs) {
        if (!doc.exists) {
          continue;
        }

        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Debug print the entire document data

        // Check for required location fields
        if (!data.containsKey('latitude') || !data.containsKey('longitude')) {
          continue;
        }

        // Validate media data
        if (data.containsKey('urls') &&
            data.containsKey('mediaTypes') &&
            data['urls'] is List &&
            data['mediaTypes'] is List) {
          List<dynamic> urls = data['urls'];
          List<dynamic> mediaTypes = data['mediaTypes'];

          if (urls.isEmpty || mediaTypes.isEmpty) {
            continue;
          }

          if (mediaTypes[0] == 'Photo' && urls[0] is String) {
            String firstUrl = urls[0];

            try {
              final post = await _getMarkerFromUrl(firstUrl);
              _addMarkerPost(
                LatLng(data['latitude'] as double, data['longitude'] as double),
                "post",
                post,
                name: data['username'] as String? ?? 'Unknown',
                ontap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostViewScreen(postId: data['key']),
                    ),
                  );
                },
              );
            } catch (e) {
              print('Error creating marker for post ${doc.id}: $e');
            }
          } else {
            print('First media is not a photo for post ${doc.id}');
          }
        } else {
          print('Post ${doc.id} missing required media fields');
        }
      }
      print('Finished processing all posts');
    } catch (e) {
      print('Error fetching photo URLs: $e');
      // For more detailed error info:
      if (e is Exception) {
        // print('Firestore error code: ${e.code}');
        // print('Firestore error message: ${e.message}');
        print('Firestore error: $e');
      }
    }
  }

  // New - Load saved locations from Firestore
  Future<void> _loadSavedLocations() async {
    try {
      final QuerySnapshot snapshot = await _savedLocationsCollection.get();

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final position = LatLng(
          data['latitude'] as double,
          data['longitude'] as double,
        );

        _addMarker(
          position,
          "saved_${data['id']}",
          await _getCustomMarkerIcon(data['icon'] ?? 'default'),
          name: data['name'],
        );
      }
    } catch (e) {
      debugPrint("Error loading saved locations: $e");
    }
  }

  // Enhanced - Add marker with improved info window
  void _addMarker(
    LatLng position,
    String id,
    BitmapDescriptor descriptor, {
    String? name,
  }) {
    final markerId = MarkerId(id);

    String title;
    BitmapDescriptor iconToUse = descriptor;

    // Customize marker based on type
    if (id == "current_location") {
      title = "Current Location";
    } else if (id == "destination") {
      title = "Destination";
      iconToUse = _destinationMarker;
    } else if (id == "origin") {
      title = "Origin";
      iconToUse = _currentLocationMarker;
    } else {
      title = name ?? "Location";
    }

    final marker = Marker(
      markerId: markerId,
      icon: iconToUse,
      position: position,
      infoWindow: InfoWindow(
        title: title,
        snippet:
            'Lat: ${position.latitude.toStringAsFixed(4)}, '
            'Lng: ${position.longitude.toStringAsFixed(4)}',
      ),
    );

    setState(() => _markers[markerId] = marker);
  }

  void _addMarkerPost(
    LatLng position,
    String id,
    BitmapDescriptor descriptor, {
    String? name,
    required VoidCallback ontap,
  }) {
    final markerId = MarkerId(id);

    String title;
    BitmapDescriptor iconToUse = descriptor;

    // Customize marker based on type
    if (id == "current_location") {
      title = "Current Location";
    } else if (id == "destination") {
      title = "Destination";
      iconToUse = _destinationMarker;
    } else if (id == "origin") {
      title = "Origin";
      iconToUse = _currentLocationMarker;
    } else {
      title = name ?? "Location";
    }

    final marker = Marker(
      markerId: markerId,
      icon: iconToUse,
      position: position,
      infoWindow: InfoWindow(
        title: title,
        snippet:
            'Lat: ${position.latitude.toStringAsFixed(4)}, '
            'Lng: ${position.longitude.toStringAsFixed(4)}',
        onTap: ontap,
      ),
    );

    setState(() => _markers[markerId] = marker);
  }

  // Enhanced - Add polyline with better styling
  void _addPolyline(List<LatLng> points) {
    const polylineId = PolylineId('route');
    final polyline = Polyline(
      polylineId: polylineId,
      color: const ui.Color.fromARGB(255, 1, 141, 240),
      points: points,
      width: 8,
      endCap: Cap.roundCap,
      startCap: Cap.roundCap,
    );

    setState(() => _polylines[polylineId] = polyline);
  }

  // Enhanced - Calculate route with error handling
  Future<void> _calculateRoute() async {
    if (_originLatitude == null || _destLatitude == null) {
      _showErrorSnackBar("Please set both origin and destination");
      return;
    }

    try {
      setState(() => _isLoading = true);

      final result = await _polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: _googleApiKey,
        request: PolylineRequest(
          origin: PointLatLng(_originLatitude!, _originLongitude!),
          destination: PointLatLng(_destLatitude!, _destLongitude!),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isNotEmpty) {
        final points =
            result.points
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();

        _addPolyline(points);

        // Adjust camera to show the entire route
        _mapController.animateCamera(
          CameraUpdate.newLatLngBounds(
            _boundsFromLatLngList(points),
            100, // padding
          ),
        );

        // Show route details
        _showRouteDetails("Unknown", "Unknown");
      } else {
        _showErrorSnackBar("No route found");
      }
    } catch (e) {
      debugPrint("Route calculation error: $e");
      _showErrorSnackBar("Error calculating route");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // New - Show route details
  void _showRouteDetails(String distance, String duration) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Distance: $distance | Duration: $duration"),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(
      northeast: LatLng(x1!, y1!),
      southwest: LatLng(x0!, y0!),
    );
  }

  // Enhanced - Show location options with more features
  void _showLocationOptions(LatLng position) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.save),
                title: const Text('Save this location'),
                onTap: () {
                  Navigator.pop(context);
                  _showSaveLocationDialog(position);
                },
              ),
              ListTile(
                leading: const Icon(Icons.navigation),
                title: const Text('Set as origin'),
                onTap: () {
                  Navigator.pop(context);
                  _setOriginManually(position);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag),
                title: const Text('Set as destination'),
                onTap: () {
                  Navigator.pop(context);
                  _setDestinationManually(position);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share location'),
                onTap: () {
                  Navigator.pop(context);
                  _shareLocation(position);
                },
              ),
            ],
          ),
    );
  }

  // Enhanced - Save location dialog with icon selection
  void _showSaveLocationDialog(LatLng position) {
    String locationName = '';
    String selectedIcon = 'default';

    final List<Map<String, dynamic>> iconOptions = [
      {'name': 'Default', 'value': 'default', 'icon': Icons.location_on},
      {'name': 'Home', 'value': 'home', 'icon': Icons.home},
      {'name': 'Work', 'value': 'work', 'icon': Icons.work},
      {'name': 'Food', 'value': 'food', 'icon': Icons.restaurant},
      {'name': 'Shopping', 'value': 'shopping', 'icon': Icons.shopping_cart},
    ];

    showDialog(
      context: context,
      builder: (context) {
        // Use StatefulBuilder to make the dialog stateful
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Save Location'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _locationNameController,
                      decoration: const InputDecoration(
                        labelText: 'Location name',
                      ),
                      onChanged: (value) => locationName = value,
                    ),
                    const SizedBox(height: 16),
                    const Text('Select an icon:'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children:
                          iconOptions.map((option) {
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedIcon = option['value'];
                                });
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color:
                                          selectedIcon == option['value']
                                              ? Colors.blue.withOpacity(0.3)
                                              : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(option['icon']),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    option['name'],
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _locationNameController.clear();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    locationName = _locationNameController.text;
                    if (locationName.isNotEmpty) {
                      _saveLocation(position, locationName, selectedIcon);
                      _locationNameController.clear();
                      Navigator.pop(context);
                    } else {
                      _showErrorSnackBar("Please enter a location name");
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void applyFilter(String filter) {
    // Implement your filtering logic here
    // For example:
    if (filter == 'Nearby') {
      // Show nearby posts/users
    } else if (filter == 'Post') {
      // Show only posts
    } else if (filter == 'Story') {
      // Show only stories
    } else if (filter == 'Places') {
      // Show only places
    }
  }

  // Enhanced - Save location with confirmation
  Future<void> _saveLocation(LatLng position, String name, String icon) async {
    try {
      setState(() => _isLoading = true);

      final locationId = const Uuid().v4();
      final newLocation = {
        'id': locationId,
        'name': name,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'icon': icon,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        // Add user data as needed
        // 'userId': currentUserId,
      };

      await _savedLocationsCollection.doc(locationId).set(newLocation);

      // Add marker for the saved location
      _addMarker(
        position,
        "saved_$locationId",
        await _getCustomMarkerIcon(icon),
        name: name,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Location saved successfully"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("Error saving location: $e");
      _showErrorSnackBar("Error saving location");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Enhanced - Get custom marker icon based on type
  Future<BitmapDescriptor> _getCustomMarkerIcon(String iconName) async {
    try {
      final ImageConfiguration imageConfiguration =
          createLocalImageConfiguration(context, size: Size(48, 48));

      switch (iconName) {
        case 'home':
          return await BitmapDescriptor.fromAssetImage(
            imageConfiguration,
            'assets/images/home_marker.png',
          );
        case 'work':
          return await BitmapDescriptor.fromAssetImage(
            imageConfiguration,
            'assets/images/work_marker.png',
          );
        case 'food':
          return await BitmapDescriptor.fromAssetImage(
            imageConfiguration,
            'assets/images/food_marker.png',
          );
        case 'shopping':
          return await BitmapDescriptor.fromAssetImage(
            imageConfiguration,
            'assets/images/shopping_marker.png',
          );
        case 'default':
        default:
          return await BitmapDescriptor.fromAssetImage(
            imageConfiguration,
            'assets/images/default_marker.png',
          );
      }
    } catch (e) {
      debugPrint("Error loading custom marker icon: $e");
      // Fallback to colored default marker if custom icons fail
      switch (iconName) {
        case 'home':
          return BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          );
        case 'work':
          return BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          );
        case 'food':
          return BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRose,
          );
        case 'shopping':
          return BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet,
          );
        case 'default':
        default:
          return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      }
    }
  }

  // New - Set origin manually from map tap
  void _setOriginManually(LatLng position) {
    setState(() {
      _originLatitude = position.latitude;
      _originLongitude = position.longitude;
    });

    _addMarker(
      position,
      "origin",
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Origin set"),
        duration: Duration(seconds: 2),
      ),
    );

    // If destination is already set, calculate route
    if (_destLatitude != null && _destLongitude != null) {
      _calculateRoute();
    }
  }

  // New - Set destination manually from map tap
  void _setDestinationManually(LatLng position) {
    setState(() {
      _destLatitude = position.latitude;
      _destLongitude = position.longitude;
    });

    _addMarker(position, "destination", _destinationMarker);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Destination set"),
        duration: Duration(seconds: 2),
      ),
    );

    // If origin is already set, calculate route
    if (_originLatitude != null && _originLongitude != null) {
      _calculateRoute();
    }
  }

  // New - Share location
  void _shareLocation(LatLng position) {
    // Implement share functionality using a share plugin
    // For example:
    // Share.share('Check out this location: https://maps.google.com/?q=${position.latitude},${position.longitude}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => LocationShareScreen(
              latitude: position.latitude,
              longitude: position.longitude,
            ),
      ),
    );
  }

  // Improved UI with cleaner structure
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interactive Map'),
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.layers),
          //   onPressed: _showMapTypesMenu,
          // ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition ?? const LatLng(0, 0),
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _setMapStyle();
            },
            markers: Set<Marker>.of(_markers.values),
            polylines: Set<Polyline>.of(_polylines.values),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onLongPress: _showLocationOptions,
            mapType: _currentMapType,
            zoomControlsEnabled: false,
            compassEnabled: true,
          ),

          // Search box
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: _showSearchOptions,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: const Text(
                            'Search for a location...',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom navigation buttons
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // FloatingActionButton(
                //   heroTag: "directions",
                //   onPressed: _showDirectionsPanel,
                //   backgroundColor: Colors.white,
                //   child: const Icon(Icons.directions, color: Colors.blue),
                // ),
                // FloatingActionButton(
                //   heroTag: "saved",
                //   onPressed: _showSavedLocations,
                //   backgroundColor: Colors.white,
                //   child: const Icon(Icons.bookmark, color: Colors.blue),
                // ),
                // FloatingActionButton(
                //   heroTag: "location",
                //   onPressed: _getCurrentLocation,
                //   backgroundColor: Colors.blue,
                //   child: const Icon(Icons.my_location, color: Colors.white),
                // ),
              ],
            ),
          ),
          DraggableScrollableSheet(
            controller: _sheetController, // Add this line

            initialChildSize: 0.07,
            minChildSize: 0.07,
            maxChildSize: 0.5,
            snapSizes: const [0.07, 0.5],
            snap: true,
            builder: (BuildContext context, scrollSheetController) {
              return Container(
                color: Colors.white,
                child: ListView(
                  controller: scrollSheetController,
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        height: 5,
                        width: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 5),
                        GestureDetector(
                          onTap: _getCurrentLocation,
                          child: Icon(Icons.location_searching_rounded),
                        ),
                        GestureDetector(
                          onTap: _showSavedLocations,
                          child: Icon(Icons.share_location_outlined),
                        ),
                        GestureDetector(
                          onTap: _showDirectionsPanel,
                          child: Icon(Icons.swap_vertical_circle_rounded),
                        ),
                        GestureDetector(
                          onTap: _expandSheetWithFocus,
                          child: Icon(Icons.search_outlined),
                        ),
                        const SizedBox(width: 5),
                      ],
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        itemCount: 4,
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final List<String> tags = [
                            'Nearby',
                            'Post',
                            'Story',
                            'Places',
                          ];
                          final isActive = activeFilter == tags[index];

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                activeFilter = tags[index];
                              });
                              // Call your filter function here
                              applyFilter(tags[index]);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isActive ? Colors.blue : Colors.black,
                                  width: isActive ? 2 : 1,
                                ),
                                color:
                                    isActive
                                        ? Colors.blue[50]
                                        : Colors.grey[200],
                              ),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 10,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                              ),
                              child: Center(
                                child: Text(
                                  tags[index],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isActive ? Colors.blue : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 5),
                    exploreCnt.explorePageDataFetched.value
                        ? Column(
                          children: [
                            // Search Field
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              child: TextField(
                                controller: exploreCnt.searchController,
                                focusNode: _searchFocusNode,
                                decoration: InputDecoration(
                                  hintText: 'Search posts...',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: GestureDetector(
                                    onTap: _listen,
                                    child: Icon(
                                      _isListening ? Icons.mic : Icons.mic_none,
                                      color:
                                          _isListening
                                              ? Colors.red
                                              : Colors.grey,
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 0,
                                  ),
                                ),
                                onChanged: (value) {
                                  exploreCnt.filterPosts(value);
                                },
                              ),
                            ),
                            const SizedBox(height: 5),
                            // GridView
                            Obx(
                              () =>
                                  exploreCnt.filteredPostDataList.isEmpty &&
                                          exploreCnt
                                              .searchController
                                              .text
                                              .isNotEmpty
                                      ? const Center(
                                        heightFactor: 5,
                                        child: Text('No posts found'),
                                      )
                                      : GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        padding: const EdgeInsets.all(10),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 2,
                                              crossAxisSpacing: 10,
                                              mainAxisSpacing: 5,
                                              childAspectRatio: 1.5,
                                            ),
                                        itemCount:
                                            exploreCnt
                                                    .searchController
                                                    .text
                                                    .isEmpty
                                                ? exploreCnt
                                                    .explorePostDataList
                                                    .length
                                                : exploreCnt
                                                    .filteredPostDataList
                                                    .length,
                                        itemBuilder: (
                                          BuildContext ctx,
                                          int index,
                                        ) {
                                          final explorePostDataObject =
                                              exploreCnt
                                                      .searchController
                                                      .text
                                                      .isEmpty
                                                  ? exploreCnt
                                                      .explorePostDataList[index]
                                                  : exploreCnt
                                                      .filteredPostDataList[index];
                                          return PostCard(
                                            image:
                                                explorePostDataObject.type ==
                                                        "Video"
                                                    ? explorePostDataObject
                                                        .thumbnail
                                                        .toString()
                                                    : explorePostDataObject
                                                        .urls
                                                        .isNotEmpty
                                                    ? explorePostDataObject
                                                        .urls[0]
                                                    : '',
                                            press: () {
                                              if (explorePostDataObject.type ==
                                                  "Video") {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (
                                                          context,
                                                        ) => VideoPlayerWidget(
                                                          videoUrl:
                                                              explorePostDataObject
                                                                  .urls[0],
                                                        ),
                                                  ),
                                                );
                                              } else {
                                                _showPostDetail(
                                                  explorePostDataObject,
                                                );
                                              }
                                            },
                                          );
                                        },
                                      ),
                            ),
                          ],
                        )
                        : Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(blue),
                          ),
                        ),
                  ],
                ),
              );
            },
          ),
          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  void _showPostDetail(PostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostViewScreen(postId: post.key)),
    );
  }

  // New - Show search options dialog
  void _showSearchOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search for a location',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          // Implement search functionality
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.location_on),
                          title: const Text('Set origin location'),
                          onTap: () {
                            Navigator.pop(context);
                            _setOriginLocation();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.flag),
                          title: const Text('Set destination location'),
                          onTap: () {
                            Navigator.pop(context);
                            _setDestinationLocation();
                          },
                        ),
                        const Divider(),
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Recent Searches',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        // Recent searches would be displayed here
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  // New - Show directions panel
  void _showDirectionsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.my_location),
                        title: const Text('Current Location'),
                        trailing: const Icon(Icons.arrow_drop_down),
                        onTap: () {
                          Navigator.pop(context);
                          if (_currentPosition != null) {
                            _setOriginManually(_currentPosition!);
                          } else {
                            _getCurrentLocation().then((_) {
                              if (_currentPosition != null) {
                                _setOriginManually(_currentPosition!);
                              }
                            });
                          }
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.location_on),
                        title: const Text('Choose destination'),
                        trailing: const Icon(Icons.arrow_drop_down),
                        onTap: () {
                          Navigator.pop(context);
                          _setDestinationLocation();
                        },
                      ),
                    ],
                  ),
                ),

                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (_originLatitude != null && _destLatitude != null) {
                      _calculateRoute();
                    } else {
                      _showErrorSnackBar(
                        "Please set both origin and destination",
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('GET DIRECTIONS'),
                ),

                const SizedBox(height: 16),

                Expanded(
                  child: ListView(
                    children: const [
                      ListTile(
                        leading: Icon(Icons.history),
                        title: Text('Recent routes will appear here'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // New - Show saved locations list
  void _showSavedLocations() async {
    try {
      setState(() => _isLoading = true);
      final QuerySnapshot snapshot = await _savedLocationsCollection.get();
      setState(() => _isLoading = false);

      if (snapshot.docs.isEmpty) {
        _showErrorSnackBar("No saved locations found");
        return;
      }

      showModalBottomSheet(
        context: context,
        builder:
            (context) => Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'Saved Locations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: snapshot.docs.length,
                    itemBuilder: (context, index) {
                      final data =
                          snapshot.docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const Icon(Icons.location_on),
                        title: Text(data['name'] ?? 'Unnamed Location'),
                        subtitle: Text(
                          'Lat: ${data['latitude'].toStringAsFixed(4)}, '
                          'Lng: ${data['longitude'].toStringAsFixed(4)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            Navigator.pop(context);
                            _deleteLocation(data['id']);
                          },
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          final position = LatLng(
                            data['latitude'] as double,
                            data['longitude'] as double,
                          );
                          _mapController.animateCamera(
                            CameraUpdate.newLatLngZoom(position, 15),
                          );

                          // Show options for this location
                          _showLocationActionDialog(position, data);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error loading saved locations: $e");
      _showErrorSnackBar("Error loading saved locations");
    }
  }

  // New - Show location action dialog
  void _showLocationActionDialog(
    LatLng position,
    Map<String, dynamic> locationData,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(locationData['name'] ?? 'Location'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Lat: ${position.latitude.toStringAsFixed(6)}\nLng: ${position.longitude.toStringAsFixed(6)}',
                ),
                const SizedBox(height: 16),
                const Text('What would you like to do?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _setOriginManually(position);
                },
                child: const Text('Set as Origin'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _setDestinationManually(position);
                },
                child: const Text('Set as Destination'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  // New - Delete saved location
  Future<void> _deleteLocation(String locationId) async {
    try {
      setState(() => _isLoading = true);

      await _savedLocationsCollection.doc(locationId).delete();

      // Remove the marker
      final markerId = MarkerId("saved_$locationId");
      setState(() {
        _markers.remove(markerId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Location deleted successfully"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("Error deleting location: $e");
      _showErrorSnackBar("Error deleting location");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Enhanced - Set origin location with search functionality
  Future<void> _setOriginLocation() async {
    // This is a placeholder for implementing a location search screen
    // You would typically navigate to a search screen and get a result back

    // For demo, let's use current location as origin
    if (_currentPosition != null) {
      setState(() {
        _originLatitude = _currentPosition!.latitude;
        _originLongitude = _currentPosition!.longitude;
      });

      _addMarker(_currentPosition!, "origin", _currentLocationMarker);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Origin set to current location"),
          duration: Duration(seconds: 2),
        ),
      );

      // If destination is already set, calculate route
      if (_destLatitude != null && _destLongitude != null) {
        _calculateRoute();
      }
    } else {
      _showErrorSnackBar("Current location not available");
    }
  }

  // Enhanced - Set destination location with search functionality
  Future<void> _setDestinationLocation() async {
    // This is a placeholder for implementing a location search screen
    // You would typically navigate to a search screen and get a result back

    // For demo purposes, show a simplified search dialog
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Set Destination'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Search for a place',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Or select from common destinations:'),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.home),
                  title: const Text('Home'),
                  onTap: () {
                    Navigator.pop(context);
                    // Set a predefined home location
                    final homePosition = const LatLng(
                      37.7749,
                      -122.4194,
                    ); // Example: San Francisco
                    _setDestinationManually(homePosition);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.work),
                  title: const Text('Work'),
                  onTap: () {
                    Navigator.pop(context);
                    // Set a predefined work location
                    final workPosition = const LatLng(
                      37.4220,
                      -122.0841,
                    ); // Example: Mountain View
                    _setDestinationManually(workPosition);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  // New - Show map types menu

  // New - Show info dialog
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Map Features'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('• Long press on map to save a location'),
                SizedBox(height: 8),
                Text('• Tap the directions button to plan a route'),
                SizedBox(height: 8),
                Text('• Tap the bookmark button to see saved locations'),
                SizedBox(height: 8),
                Text('• Tap the location button to center on your position'),
                SizedBox(height: 8),
                Text('• Your position updates in real-time as you move'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ],
          ),
    );
  }

  // New - Show permission denied dialog
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Location Permission Required'),
            content: const Text(
              'This app needs location permission to show your current position on the map. '
              'Please enable location permission in your device settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  // New - Show permission denied forever dialog
  void _showPermissionDeniedForeverDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Location Permission Required'),
            content: const Text(
              'This app needs location permission to show your current position on the map. '
              'You have permanently denied this permission. Please enable it in your '
              'device settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Geolocator.openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }

  // New - Show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // Enhanced - Set map style with custom style
  Future<void> _setMapStyle() async {
    String style = await rootBundle.loadString('assets/map_style.json');
    _mapController.setMapStyle(style);
  }

  @override
  void dispose() {
    // Cancel position stream subscription
    _positionStreamSubscription?.cancel();

    // Dispose controllers
    _mapController.dispose();
    _locationNameController.dispose();
    super.dispose();
  }
}
