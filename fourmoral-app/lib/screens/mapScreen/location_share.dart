import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/models/contacts_model.dart';
import 'package:fourmoral/screens/contactsScreen/contacts_services.dart';
import 'package:fourmoral/screens/messageScreen/message_screen.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LocationShareScreen extends StatefulWidget {
  final double latitude;
  final double longitude;

  const LocationShareScreen({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<LocationShareScreen> createState() => _LocationShareScreenState();
}

class _LocationShareScreenState extends State<LocationShareScreen> {
  final ContactsScreenCnt controller = Get.put(ContactsScreenCnt());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Share Location'),
        backgroundColor: blue,
        foregroundColor: black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              _shareLocation();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Map container
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: FlutterMap(
                  options: MapOptions(
                    minZoom: 13.0,
                    maxZoom: 18.0,
                    initialCenter: LatLng(widget.latitude, widget.longitude),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(widget.latitude, widget.longitude),
                          width: 40,
                          height: 40,
                          child: Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Location details
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.indigo.shade200,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '${widget.latitude.toStringAsFixed(6)}, ${widget.longitude.toStringAsFixed(6)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.copy, size: 20),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(
                                  text:
                                      '${widget.latitude},${widget.longitude}',
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Coordinates copied to clipboard',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: black,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      'Share',
                      Icons.share,
                      Colors.blue,
                      () => _shareLocation(),
                    ),
                    _buildActionButton(
                      'Directions',
                      Icons.directions,
                      Colors.green,
                      () => _openDirections(),
                    ),
                    _buildActionButton(
                      'Share Story',
                      Icons.auto_stories,
                      Colors.purple,
                      () => _shareStory(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Users list section
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.indigo.shade100,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.people, color: black),
                      SizedBox(width: 8),
                      Text(
                        'Share with Contacts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: black,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Obx(() {
                    if (!controller.contactsDataFetched.value) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (controller.contactsDataList.isEmpty) {
                      return Center(child: Text('No contacts available'));
                    }
                    return ListView.builder(
                      itemCount: controller.contactsDataList.length,
                      itemBuilder: (context, index) {
                        final user = controller.contactsDataList[index];
                        return _buildContactTile(user);
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserListItem(ContactsModel user) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: CachedNetworkImageProvider(user.profilePicture),
        ),
        title: Text(user.name, style: TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          user.username,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        trailing: IconButton(
          icon: Icon(Icons.send_rounded, color: black),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => Message(
                      userimg: user.profilePicture,
                      username: user.username,
                      profileuserphone: user.mobileNumber,
                      locationLat: widget.latitude,
                      locationLong: widget.longitude,
                    ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContactTile(ContactsModel user) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundImage: NetworkImage(user.profilePicture),
        radius: 24,
      ),
      title: Text(user.name, style: TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(user.mobileNumber),
      trailing: IconButton(
        icon: Icon(Icons.send_rounded, color: black),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => Message(
                    userimg: user.profilePicture,
                    username: user.username,
                    profileuserphone: user.mobileNumber,
                    locationLat: widget.latitude,
                    locationLong: widget.longitude,
                  ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  void _shareLocation() {
    Share.share(
      'Check out this location:\nLatitude: ${widget.latitude}\nLongitude: ${widget.longitude}\n\nhttps://www.google.com/maps?q=${widget.latitude},${widget.longitude}',
    );
  }

  void _openDirections() {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${widget.latitude},${widget.longitude}';
    // Open URL in browser - would use url_launcher package in a real app
    print('Opening directions: $url');
  }

  void _shareStory() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Location added to your story'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.purple,
      ),
    );
  }
}
