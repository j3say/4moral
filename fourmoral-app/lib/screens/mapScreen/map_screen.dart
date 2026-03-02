import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/models/post_model.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/explorePageScreen/explore_controller.dart';
import 'package:fourmoral/screens/mapScreen/loaction_search_screen.dart';
import 'package:fourmoral/screens/mapScreen/location_share.dart';
import 'package:fourmoral/screens/mapScreen/navigation_search.dart';
import 'package:fourmoral/screens/mapScreen/video_player_widget.dart';
import 'package:fourmoral/screens/postViewScreen/post_view_screen.dart';
import 'package:fourmoral/screens/profileScreen/profile_widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:uuid/uuid.dart';

class MapScreen2 extends StatefulWidget {
  const MapScreen2({super.key, this.initialLatitude, this.initialLongitude});
  final double? initialLatitude;
  final double? initialLongitude;
  @override
  _MapScreen2State createState() => _MapScreen2State();
}

class _MapScreen2State extends State<MapScreen2> {
  final exploreCnt = Get.put(ExploreCnt());
  String activeFilter = 'Nearby';
  late GoogleMapController mapController;
  double? _originLatitude, _originLongitude;
  double? _destLatitude, _destLongitude;
  BitmapDescriptor _defaultMarker = BitmapDescriptor.defaultMarker;

  Map<MarkerId, Marker> markers = {};
  Map<PolylineId, Polyline> polylines = {};
  final TextEditingController _locationNameController = TextEditingController();
  final CollectionReference _savedLocationsCollection = FirebaseFirestore
      .instance
      .collection('saved_locations');
  final RxList<SavedLocation> _savedLocations = <SavedLocation>[].obs;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _lastWords = '';
  String _selectedIcon = 'default';
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  final FocusNode _searchFocusNode = FocusNode();
  bool _shouldFocusSearch = false;

  // Add this method to handle sheet expansion with focus
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

  final List<Map<String, dynamic>> _availableIcons = [
    {'name': 'default', 'icon': Icons.location_on},
    {'name': 'home', 'icon': Icons.home},
    {'name': 'work', 'icon': Icons.work},
    {'name': 'favorite', 'icon': Icons.favorite},
    {'name': 'restaurant', 'icon': Icons.restaurant},
    {'name': 'hotel', 'icon': Icons.hotel},
    {'name': 'park', 'icon': Icons.park},
    {'name': 'shopping', 'icon': Icons.shopping_cart},
  ];
  PolylinePoints polylinePoints = PolylinePoints();
  String googleAPiKey = "AIzaSyCjirUlgby1lfV8BxagtICEBWxlsk1RZlY";

  var _pickUpLocationSC = StreamController<PlaceDetail>.broadcast();

  StreamSink<PlaceDetail> get pickUpLocationSink => _pickUpLocationSC.sink;

  Stream<PlaceDetail> get pickUpLocationStream => _pickUpLocationSC.stream;

  var _dropUpLocationSC = StreamController<PlaceDetail>.broadcast();

  StreamSink<PlaceDetail> get dropLocationSink => _dropUpLocationSC.sink;

  Stream<PlaceDetail> get dropLocationStream => _dropUpLocationSC.stream;

  List<Suggestion> suggestion = [];
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  DateTime? _selectedAlarmDateTime;
  bool _enableAlarm = false;
  final provider = PlaceApiProvider(const Uuid().v4());
  void _initializeNotifications() async {
    tz_data.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _relocateToCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: _selectedAccuracy,
      );

      // Update current position
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      // Clear existing current location markers
      markers.removeWhere((key, value) => key.value == "current_location");

      // Add new marker for current location
      _addMarker(
        _currentPosition!,
        "current_location",
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );

      // Move camera to current location
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition!, 15),
      );

      // Update Firestore with new location
      await collectionUserReference
          .where('mobileNumber', isEqualTo: profileDataModel?.mobileNumber)
          .get()
          .then((value) {
            value.docs[0].reference.update({
              'latitude': position.latitude,
              'longLatitude': position.longitude,
            });
          });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error relocating: ${e.toString()}')),
      );
    }
  }

  Future<void> _scheduleLocationAlarm(
    String locationName,
    String locationId,
  ) async {
    if (!_enableAlarm || _selectedAlarmDateTime == null) return;

    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'location_alarms',
      'Location Alarms',
      channelDescription: 'Notifications for saved location alarms',
      importance: Importance.max,
      priority: Priority.high,
    );

    final iOSPlatformChannelSpecifics = DarwinNotificationDetails();

    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      locationId.hashCode, // Use the location ID hash as the notification ID
      'Location Reminder',
      'Time to visit $locationName',
      tz.TZDateTime.from(_selectedAlarmDateTime!, tz.local),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exact,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
      payload: locationId,
    );

    print(
      'Alarm scheduled for $locationName at ${_selectedAlarmDateTime!.toString()}',
    );
  }

  Future<void> _loadSavedLocations() async {
    try {
      final userId = profileDataModel?.mobileNumber ?? '';
      print('Loading saved locations for user: $userId'); // Debug print

      if (userId.isEmpty) {
        print('User ID is empty, cannot load locations');
        return;
      }

      final querySnapshot =
          await _savedLocationsCollection
              .where('userId', isEqualTo: userId)
              .orderBy('timestamp', descending: true)
              .get();

      print('Found ${querySnapshot.docs.length} locations'); // Debug print

      _savedLocations.value =
          querySnapshot.docs.map((doc) {
            print('Location data: ${doc.data()}'); // Debug print
            return SavedLocation.fromMap(doc.data() as Map<String, dynamic>);
          }).toList();
    } catch (e) {
      print('Error loading saved locations: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading locations: $e')));
    }
  }

  void _addMarker(LatLng position, String id, BitmapDescriptor descriptor) {
    final MarkerId markerId = MarkerId(id);
    final Marker marker = Marker(
      markerId: markerId,
      icon: descriptor,
      position: position,
      infoWindow: InfoWindow(
        snippet:
            'Lat: ${position.latitude.toStringAsFixed(4)}, '
            'Lng: ${position.longitude.toStringAsFixed(4)}',
        title:
            id.startsWith("saved_")
                ? _savedLocations
                    .firstWhere(
                      (loc) => loc.id == id.replaceFirst("saved_", ""),
                      orElse:
                          () => SavedLocation(
                            id: '',
                            name: 'Unknown',
                            latitude: 0,
                            longitude: 0,
                            userId: '',
                            username: '',
                            timestamp: DateTime.now(),
                          ),
                    )
                    .name
                : id == "origin"
                ? "Origin"
                : "Destination",
      ),
      onTap: () {
        if (id.startsWith("saved_")) {
          // Handle saved location tap
        }
      },
    );

    setState(() {
      markers[markerId] = marker;
    });
  }

  Future<void> _saveCurrentLocation() async {
    if (_currentPosition == null) return;

    final userId = profileDataModel?.mobileNumber ?? '';
    final username = profileDataModel?.username ?? 'Unknown';

    if (userId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not logged in')));
      return;
    }

    // Reset alarm state for the new dialog
    setState(() {
      _enableAlarm = false;
      _selectedAlarmDateTime = null;
    });

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
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
                          hintText: 'Enter location name',
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Select an icon:'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children:
                            _availableIcons.map((iconData) {
                              return ChoiceChip(
                                label: Icon(iconData['icon']),
                                selected: _selectedIcon == iconData['name'],
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedIcon = iconData['name'];
                                  });
                                },
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 20),
                      // Alarm section
                      Row(
                        children: [
                          Checkbox(
                            value: _enableAlarm,
                            onChanged: (value) {
                              setState(() {
                                _enableAlarm = value ?? false;
                                if (_enableAlarm &&
                                    _selectedAlarmDateTime == null) {
                                  _selectedAlarmDateTime = DateTime.now().add(
                                    const Duration(hours: 1),
                                  );
                                }
                              });
                            },
                          ),
                          const Text('Set Alarm'),
                        ],
                      ),
                      if (_enableAlarm) ...[
                        const SizedBox(height: 10),
                        OutlinedButton(
                          child: Text(
                            _selectedAlarmDateTime != null
                                ? 'Alarm: ${DateFormat('MMM dd, yyyy - hh:mm a').format(_selectedAlarmDateTime!)}'
                                : 'Set Alarm Time',
                          ),
                          onPressed: () async {
                            final DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate:
                                  _selectedAlarmDateTime ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );

                            if (pickedDate != null) {
                              final TimeOfDay? pickedTime =
                                  await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(
                                      _selectedAlarmDateTime ??
                                          DateTime.now().add(
                                            const Duration(hours: 1),
                                          ),
                                    ),
                                  );

                              if (pickedTime != null) {
                                setState(() {
                                  _selectedAlarmDateTime = DateTime(
                                    pickedDate.year,
                                    pickedDate.month,
                                    pickedDate.day,
                                    pickedTime.hour,
                                    pickedTime.minute,
                                  );
                                });
                              }
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (_locationNameController.text.isNotEmpty) {
                        try {
                          final locationId = const Uuid().v4();
                          final newLocation = SavedLocation(
                            id: locationId,
                            name: _locationNameController.text,
                            latitude: _currentPosition!.latitude,
                            longitude: _currentPosition!.longitude,
                            userId: userId,
                            username: username,
                            timestamp: DateTime.now(),
                            icon: _selectedIcon,
                            hasAlarm: _enableAlarm,
                            alarmDateTime:
                                _enableAlarm ? _selectedAlarmDateTime : null,
                          );

                          await _savedLocationsCollection
                              .doc(locationId)
                              .set(newLocation.toMap());

                          // Schedule alarm if enabled
                          if (_enableAlarm && _selectedAlarmDateTime != null) {
                            await _scheduleLocationAlarm(
                              _locationNameController.text,
                              locationId,
                            );
                          }

                          _locationNameController.clear();
                          Navigator.pop(context);
                          _loadSavedLocations();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _enableAlarm
                                    ? 'Location saved with alarm!'
                                    : 'Location saved!',
                              ),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error saving location: $e'),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _deleteLocation(String locationId) async {
    try {
      // Cancel the alarm if it exists
      await flutterLocalNotificationsPlugin.cancel(locationId.hashCode);

      // Delete the location from Firestore
      await _savedLocationsCollection.doc(locationId).delete();

      _loadSavedLocations(); // Refresh the list
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Location deleted')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting location: $e')));
    }
  }

  Future<BitmapDescriptor> _getMarkerIcon(String iconName) async {
    // Default marker if no icon specified
    if (iconName == 'default') {
      return BitmapDescriptor.defaultMarker;
    }

    // Find the matching icon data
    final iconData = _availableIcons.firstWhere(
      (icon) => icon['name'] == iconName,
      orElse: () => _availableIcons.first,
    );

    // Create a custom marker with the selected icon
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Draw the icon
    final icon = iconData['icon'] as IconData;
    final builder = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: 100,
        color: Colors.red, // Customize color
        fontFamily: icon.fontFamily,
      ),
    );

    textPainter.text = builder;
    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);

    final image = await pictureRecorder.endRecording().toImage(
      textPainter.width.toInt(),
      textPainter.height.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  void _showSavedLocations() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Obx(
            () => Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Saved Locations',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.bookmark_border_rounded),
                        onPressed: _saveCurrentLocation,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child:
                        _savedLocations.isEmpty
                            ? const Center(child: Text('No saved locations'))
                            : ListView.builder(
                              itemCount: _savedLocations.length,
                              itemBuilder: (context, index) {
                                final location = _savedLocations[index];
                                final iconData = _availableIcons.firstWhere(
                                  (icon) => icon['name'] == location.icon,
                                  orElse: () => _availableIcons.first,
                                );

                                return ListTile(
                                  leading: Icon(iconData['icon']),
                                  title: Text(location.name),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Saved on ${DateFormat('MMM dd, yyyy').format(location.timestamp)}',
                                      ),
                                      if (location.hasAlarm &&
                                          location.alarmDateTime != null)
                                        Text(
                                          'Alarm: ${DateFormat('MMM dd, yyyy - hh:mm a').format(location.alarmDateTime!)}',
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                  onTap: () async {
                                    final markerIcon = await _getMarkerIcon(
                                      location.icon,
                                    );
                                    _addMarker(
                                      LatLng(
                                        location.latitude,
                                        location.longitude,
                                      ),
                                      "saved_${location.id}",
                                      markerIcon,
                                    );
                                    mapController.animateCamera(
                                      CameraUpdate.newLatLngZoom(
                                        LatLng(
                                          location.latitude,
                                          location.longitude,
                                        ),
                                        15,
                                      ),
                                    );
                                    Navigator.pop(context);
                                  },
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (location.hasAlarm)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.alarm,
                                            color: Colors.orange,
                                          ),
                                          onPressed: () {
                                            // Show alarm details or edit alarm
                                            _editLocationAlarm(location);
                                          },
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed:
                                            () => _deleteLocation(location.id),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _editLocationAlarm(SavedLocation location) {
    setState(() {
      _enableAlarm = location.hasAlarm;
      _selectedAlarmDateTime = location.alarmDateTime;
    });

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text('Alarm for ${location.name}'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _enableAlarm,
                          onChanged: (value) {
                            setState(() {
                              _enableAlarm = value ?? false;
                              if (_enableAlarm &&
                                  _selectedAlarmDateTime == null) {
                                _selectedAlarmDateTime = DateTime.now().add(
                                  const Duration(hours: 1),
                                );
                              }
                            });
                          },
                        ),
                        const Text('Enable Alarm'),
                      ],
                    ),
                    if (_enableAlarm) ...[
                      const SizedBox(height: 10),
                      OutlinedButton(
                        child: Text(
                          _selectedAlarmDateTime != null
                              ? 'Alarm: ${DateFormat('MMM dd, yyyy - hh:mm a').format(_selectedAlarmDateTime!)}'
                              : 'Set Alarm Time',
                        ),
                        onPressed: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate:
                                _selectedAlarmDateTime ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );

                          if (pickedDate != null) {
                            final TimeOfDay? pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(
                                _selectedAlarmDateTime ??
                                    DateTime.now().add(
                                      const Duration(hours: 1),
                                    ),
                              ),
                            );

                            if (pickedTime != null) {
                              setState(() {
                                _selectedAlarmDateTime = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                              });
                            }
                          }
                        },
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        // Cancel any existing alarms for this location
                        await flutterLocalNotificationsPlugin.cancel(
                          location.id.hashCode,
                        );

                        // Update the location with new alarm settings
                        final updatedLocation = SavedLocation(
                          id: location.id,
                          name: location.name,
                          latitude: location.latitude,
                          longitude: location.longitude,
                          userId: location.userId,
                          username: location.username,
                          timestamp: location.timestamp,
                          icon: location.icon,
                          hasAlarm: _enableAlarm,
                          alarmDateTime:
                              _enableAlarm ? _selectedAlarmDateTime : null,
                        );

                        await _savedLocationsCollection
                            .doc(location.id)
                            .update(updatedLocation.toMap());

                        // Schedule new alarm if enabled
                        if (_enableAlarm && _selectedAlarmDateTime != null) {
                          await _scheduleLocationAlarm(
                            location.name,
                            location.id,
                          );
                        }

                        Navigator.pop(context);
                        _loadSavedLocations();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _enableAlarm
                                  ? 'Alarm updated!'
                                  : 'Alarm disabled',
                            ),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error updating alarm: $e')),
                        );
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          ),
    );
  }

  void _showPostDetail(PostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostViewScreen(postId: post.key)),
    );
  }

  void applyFilter(String filter) {
    // Implement your filtering logic here
    // For example:
    if (filter == 'Nearby') {
      // Show nearby posts/users
      loadData(); // Reload with nearby filter
    } else if (filter == 'Post') {
      // Show only posts
    } else if (filter == 'Story') {
      // Show only stories
    } else if (filter == 'Places') {
      // Show only places
    }
  }

  Future<LatLng> _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    return LatLng(position.latitude, position.longitude);
  }

  Future<void> loadData({String? filter}) async {
    try {
      // Clear existing markers
      _markers.clear();

      if (filter == null || filter == 'Nearby') {
      } else if (filter == 'Post') {}
      QuerySnapshot userSnapshot = await collectionUserReference.get();
      List userData = userSnapshot.docs.map((doc) => doc.data()).toList();

      for (int i = 0; i < userData.length; i++) {
        if (userData[i]['latitude'] != null &&
            userData[i]['longLatitude'] != null) {
          BitmapDescriptor markerIcon = _defaultMarker;

          if (userData[i]['profilePicture'] != null &&
              userData[i]['profilePicture'] != "null") {
            try {
              markerIcon = await getMarkerIcon(
                userData[i]['profilePicture'],
                const Size(150.0, 150.0),
                userData[i]['type'] ?? 'User',
              );
            } catch (e) {
              print('Error creating user marker icon: $e');
              markerIcon = _defaultMarker;
            }
          }

          _markers.add(
            Marker(
              markerId: MarkerId('user_${userData[i]['mobileNumber']}'),
              icon: markerIcon,
              position: LatLng(
                userData[i]['latitude'],
                userData[i]['longLatitude'],
              ),
              infoWindow: InfoWindow(title: '${userData[i]['username']}'),
            ),
          );
        }
      }

      // 2. Load only posts from the last 24 hours
      DateTime now = DateTime.now();
      DateTime twentyFourHoursAgo = now.subtract(const Duration(hours: 24));

      QuerySnapshot postSnapshot =
          await FirebaseFirestore.instance
              .collection('Posts')
              .where('hasLocation', isEqualTo: true)
              .where('createdAt', isGreaterThanOrEqualTo: twentyFourHoursAgo)
              .get();

      for (int i = 0; i < postSnapshot.docs.length; i++) {
        var postData = postSnapshot.docs[i].data() as Map<String, dynamic>;

        if (postData['latitude'] != null && postData['longitude'] != null) {
          BitmapDescriptor markerIcon = _defaultMarker;

          if (postData['urls'] != null &&
              (postData['urls'] as List).isNotEmpty) {
            try {
              markerIcon = await BitmapDescriptor.fromAssetImage(
                ImageConfiguration(size: Size(48, 48)), // Adjust size as needed
                'assets/logo.png',
              );
            } catch (e) {
              print('Error creating post marker icon: $e');
              markerIcon = _defaultMarker;
            }
          }

          _markers.add(
            Marker(
              markerId: MarkerId('post_${postData['key']}'),
              icon: await BitmapDescriptor.fromAssetImage(
                ImageConfiguration(size: Size(48, 48)), // Adjust size as needed
                'assets/logo.png',
              ),
              position: LatLng(postData['latitude'], postData['longitude']),
              infoWindow: InfoWindow(
                title: postData['username'] ?? 'Unknown',
                snippet: 'Tap to view post',
              ),
              onTap: () {
                _showPostDetail(PostModel.fromJson(postData));
              },
            ),
          );
        }
      }

      setState(() {});
    } catch (e) {
      print("Error loading data: ${e.toString()}");
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    return await Geolocator.getCurrentPosition();
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
              _lastWords = result.recognizedWords;
              exploreCnt.searchController.text = _lastWords;
              exploreCnt.filterPosts(_lastWords);
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

  bool _isLoading = true;
  LatLng? _currentPosition;
  final LocationAccuracy _selectedAccuracy = LocationAccuracy.high;

  // created empty list of markers
  final List<Marker> _markers = <Marker>[];

  CollectionReference collectionUserReference = FirebaseFirestore.instance
      .collection('Users');

  Future<ui.Image> getImageFromPath(String imagePath) async {
    try {
      // Skip if invalid URL
      if (!imagePath.startsWith('http')) {
        throw Exception('Invalid image URL');
      }

      final response = await http
          .get(Uri.parse(imagePath), headers: {'Accept': 'image/*'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to load image: ${response.statusCode}');
      }

      final bytes = response.bodyBytes;
      if (bytes.isEmpty) throw Exception('Empty image data');

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      print('Error loading image: $e');
      // Fallback to default marker
      final ByteData data = await rootBundle.load('assets/default_marker.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    }
  }

  Future<BitmapDescriptor> getMarkerIcon(
    String imagePath,
    Size size,
    String type,
  ) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Calculate proportional sizes based on the new dimensions
    final double shadowWidth = size.width * 0.075; // 15 for 200
    final double borderWidth = size.width * 0.015; // 3 for 200
    final double imageOffset = shadowWidth + borderWidth;

    TextSpan span = TextSpan(
      style: TextStyle(
        height: 1.2,
        color: Colors.white,
        fontSize: size.width * 0.1, // 20 for 200
        fontWeight: FontWeight.bold,
      ),
      text: type,
    );

    TextPainter tp = TextPainter(text: span, textAlign: TextAlign.center);

    tp.layout();

    // TEXT BOX BACKGROUND
    Paint textBgBoxPaint = Paint()..color = Colors.black;

    // Adjust positions proportionally
    Rect rect = Rect.fromLTWH(
      size.width * 0.2, // 40 for 200
      size.height * 0.575, // 115 for 200
      tp.width + size.width * 0.1, // 20 for 200
      size.height * 0.175, // 35 for 200
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(size.width * 0.05),
      ), // 10 for 200
      textBgBoxPaint,
    );

    //ADD TEXT WITH ALIGN TO CANVAS
    tp.paint(
      canvas,
      Offset(size.width * 0.25, size.height * 0.6),
    ); // 50,120 for 200

    // Oval for the image
    Rect oval = Rect.fromLTWH(
      imageOffset,
      0,
      size.width - (imageOffset * 2),
      size.height - (imageOffset * 2),
    );

    // Add path for oval image
    canvas.clipPath(Path()..addOval(oval));

    // Add image
    ui.Image image = await getImageFromPath(imagePath);
    paintImage(canvas: canvas, image: image, rect: oval, fit: BoxFit.fitWidth);

    // Convert canvas to image
    final ui.Image markerAsImage = await pictureRecorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );

    // Convert image to bytes
    final ByteData? byteData = await markerAsImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final Uint8List uint8List = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(uint8List);
  }

  Future<void> getLocation() async {
    try {
      // Ask for location permission
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print("Location permission denied");
        return;
      }

      // Optional: Detect Android 12+
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 31) {
          print("Android 12+ device: user may have set approximate location.");
        }
      }

      // Get location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: _selectedAccuracy,
      );

      double lat = position.latitude;
      double long = position.longitude;

      // Update Firestore
      await collectionUserReference
          .where('mobileNumber', isEqualTo: profileDataModel?.mobileNumber)
          .get()
          .then((value) {
            value.docs[0].reference.update({
              'latitude': lat,
              'longLatitude': long,
            });
          });

      setState(() {
        _currentPosition = LatLng(lat, long);
      });

      print("Updated location: $lat, $long");
    } catch (e) {
      print("Error getting location: ${e.toString()}");
    }
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadSavedLocations();
    _initializeNotifications();
    _pickUpLocationSC = StreamController<PlaceDetail>.broadcast();
    _dropUpLocationSC = StreamController<PlaceDetail>.broadcast();
    exploreCnt.getExplorePageData();
    _initDefaultMarker();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        setState(() {
          _isLoading = true;
        });

        // Check if initial coordinates were provided
        if (widget.initialLatitude != null && widget.initialLongitude != null) {
          setState(() {
            _currentPosition = LatLng(
              widget.initialLatitude!,
              widget.initialLongitude!,
            );
          });

          // Add marker for the initial position
          _addMarker(
            _currentPosition!,
            "initial_location",
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          );

          // Move camera to the initial position
          mapController.animateCamera(
            CameraUpdate.newLatLngZoom(_currentPosition!, 15),
          );
        } else {
          // Fall back to current location if no initial coordinates provided
          await getLocation();
        }

        await loadData();
        setState(() {
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _initDefaultMarker() async {
    try {
      // Option 1: Use default marker
      _defaultMarker = BitmapDescriptor.defaultMarker;

      // Option 2: Load custom marker from assets
      // _defaultMarker = await BitmapDescriptor.fromAssetImage(
      //   const ImageConfiguration(size: Size(48, 48)),
      //   'assets/default_marker.png',
      // );
    } catch (e) {
      print('Error initializing default marker: $e');
    }
  }

  int selectedCarId = 1;
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                  children: [
                    GoogleMap(
                      onLongPress: (LatLng position) {
                        // Clear any existing long-press markers
                        _clearLongPressMarkers();
                        // Show options and drop a pin
                        _showPinOptions(position);
                      },
                      mapToolbarEnabled: false,
                      initialCameraPosition: CameraPosition(
                        target:
                            _currentPosition ??
                            const LatLng(28.6139, 77.2090), // Fallback position
                        zoom: 15,
                      ),
                      myLocationEnabled: true, // Changed to true for better UX
                      myLocationButtonEnabled: true,
                      tiltGesturesEnabled: true,
                      compassEnabled: true,
                      scrollGesturesEnabled: true,
                      zoomGesturesEnabled: true,
                      onMapCreated: (controller) {
                        mapController = controller;
                        _onMapCreated(controller);
                      },
                      mapType:
                          MapType
                              .normal, // Changed from terrain to normal for better clarity
                      markers: Set<Marker>.of(
                        markers.isNotEmpty ? markers.values : _markers,
                      ),
                      polylines: Set<Polyline>.of(polylines.values),
                      onCameraMove: (position) {
                        // Optional: handle camera movement
                      },
                    ),
                    Column(
                      children: [
                        const SizedBox(height: 50),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            textStyle: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(21),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: StreamBuilder<PlaceDetail>(
                                  stream: pickUpLocationStream,
                                  builder: (context, snapshot) {
                                    final address =
                                        snapshot.data?.address ??
                                        "Enter From location";

                                    if (snapshot.hasData) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            _originLatitude =
                                                snapshot.data!.latitude;
                                            _originLongitude =
                                                snapshot.data!.longitude;
                                            _addMarker(
                                              LatLng(
                                                _originLatitude!,
                                                _originLongitude!,
                                              ),
                                              "origin",
                                              BitmapDescriptor.defaultMarker,
                                            );
                                          });
                                    }

                                    return Text(
                                      address,
                                      maxLines: 1,
                                      textAlign: TextAlign.start,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => LocationSearchScreen(
                                      title: "Enter From Location",
                                      sink: pickUpLocationSink,
                                    ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            textStyle: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(21),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: StreamBuilder<PlaceDetail>(
                                  stream: dropLocationStream,
                                  builder: (context, snapshot) {
                                    final address =
                                        snapshot.data?.address ??
                                        "Enter To location";

                                    if (snapshot.hasData) {
                                      WidgetsBinding.instance.addPostFrameCallback((
                                        _,
                                      ) {
                                        _destLatitude = snapshot.data!.latitude;
                                        _destLongitude =
                                            snapshot.data!.longitude;
                                        _addMarker(
                                          LatLng(
                                            _destLatitude!,
                                            _destLongitude!,
                                          ),
                                          "destination",
                                          BitmapDescriptor.defaultMarkerWithHue(
                                            90,
                                          ),
                                        );
                                      });
                                    }

                                    return Text(
                                      address,
                                      maxLines: 1,
                                      textAlign: TextAlign.start,
                                    );
                                  },
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  _getPolyline();
                                },
                                child: const Icon(Icons.search),
                              ),
                            ],
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => LocationSearchScreen(
                                      title: "Enter To Location",
                                      sink: dropLocationSink,
                                    ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
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
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 5,
                                  ),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const SizedBox(width: 5),
                                  GestureDetector(
                                    onTap: () async {
                                      LatLng currentLatLng =
                                          await _getCurrentLocation();
                                      mapController.animateCamera(
                                        CameraUpdate.newLatLng(currentLatLng),
                                      );
                                    },
                                    child: Icon(
                                      Icons.location_searching_rounded,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _showSavedLocations,
                                    child: Icon(Icons.share_location_outlined),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      // Get current camera position
                                      mapController
                                          .getLatLng(
                                            ScreenCoordinate(x: 0, y: 0),
                                          )
                                          .then((latLng) {
                                            _showPinOptions(latLng);
                                          });
                                    },
                                    child: Icon(Icons.share),
                                  ),
                                  const Icon(
                                    Icons.swap_vertical_circle_rounded,
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
                                    final isActive =
                                        activeFilter == tags[index];

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
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color:
                                                isActive
                                                    ? Colors.blue
                                                    : Colors.black,
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
                                                  isActive
                                                      ? Colors.blue
                                                      : Colors.black,
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
                                          controller:
                                              exploreCnt.searchController,
                                          focusNode: _searchFocusNode,
                                          decoration: InputDecoration(
                                            hintText: 'Search posts...',
                                            prefixIcon: const Icon(
                                              Icons.search,
                                            ),
                                            suffixIcon: GestureDetector(
                                              onTap: _listen,
                                              child: Icon(
                                                _isListening
                                                    ? Icons.mic
                                                    : Icons.mic_none,
                                                color:
                                                    _isListening
                                                        ? Colors.red
                                                        : Colors.grey,
                                              ),
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
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
                                            exploreCnt
                                                        .filteredPostDataList
                                                        .isEmpty &&
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
                                                  padding: const EdgeInsets.all(
                                                    10,
                                                  ),
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
                                                          explorePostDataObject
                                                                      .type ==
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
                                                        if (explorePostDataObject
                                                                .type ==
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
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        blue,
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) async {
    mapController = controller;
    try {
      String style = await rootBundle.loadString('assets/map_style.json');
      mapController.setMapStyle(style);
    } catch (e) {
      print("Error loading map style: $e");
    }
  }

  void _addPolyLine(List<LatLng> polylineCoordinates) {
    final PolylineId id = const PolylineId('poly');
    final Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.blue,
      points: polylineCoordinates,
      width: 5,
      geodesic: true,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    );

    setState(() {
      polylines[id] = polyline;
    });
  }

  _getPolyline() async {
    if (_originLatitude == null || _destLatitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both origin and destination'),
        ),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: googleAPiKey,
        request: PolylineRequest(
          origin: PointLatLng(_originLatitude!, _originLongitude!),
          destination: PointLatLng(_destLatitude!, _destLongitude!),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isNotEmpty) {
        List<LatLng> points =
            result.points
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();
        _addPolyLine(points);

        // Adjust camera to show both markers and route
        mapController.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(
                min(_originLatitude!, _destLatitude!),
                min(_originLongitude!, _destLongitude!),
              ),
              northeast: LatLng(
                max(_originLatitude!, _destLatitude!),
                max(_originLongitude!, _destLongitude!),
              ),
            ),
            100, // padding
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showPinOptions(LatLng position) {
    // Add a marker at the long-pressed position
    final markerId = MarkerId(
      'long_press_${DateTime.now().millisecondsSinceEpoch}',
    );
    _addMarker(
      position,
      markerId.value,
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.location_pin),
                title: const Text('Pin this location'),
                onTap: () {
                  Navigator.pop(context);
                  // The pin is already added, just show a confirmation
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Location pinned')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share this location'),
                onTap: () {
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
                },
              ),
              ListTile(
                leading: const Icon(Icons.save),
                title: const Text('Save this location'),
                onTap: () {
                  Navigator.pop(context);
                  _saveCustomLocation(position);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _saveCustomLocation(LatLng position) {
    setState(() {
      _currentPosition = position;
    });
    _saveCurrentLocation(); // Reuse your existing save method
  }

  void _clearLongPressMarkers() {
    setState(() {
      markers.removeWhere((key, value) => key.value.startsWith('long_press_'));
    });
  }
}

class SavedLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String userId;
  final String username;
  final DateTime timestamp;
  final String icon;
  final bool hasAlarm; // New field
  final DateTime? alarmDateTime; // New field

  SavedLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.userId,
    required this.username,
    required this.timestamp,
    this.icon = 'default',
    this.hasAlarm = false,
    this.alarmDateTime,
  });

  factory SavedLocation.fromMap(Map<String, dynamic> map) {
    return SavedLocation(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      userId: map['userId'] ?? '',
      username: map['username'] ?? 'Unknown',
      timestamp:
          map['timestamp'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
              : DateTime.now(),
      icon: map['icon'] ?? 'default',
      hasAlarm: map['hasAlarm'] ?? false,
      alarmDateTime:
          map['alarmDateTime'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['alarmDateTime'] as int)
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'userId': userId,
      'username': username,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'icon': icon,
      'hasAlarm': hasAlarm,
      'alarmDateTime': alarmDateTime?.millisecondsSinceEpoch,
    };
  }
}
