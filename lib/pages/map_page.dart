import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late GoogleMapController mapController;
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref(
        'crowd_monitor/zone_A',
      );

  // Defaulted exactly to Rosary College of Commerce & Arts, Navelim, Goa!
  LatLng _currentLocation = const LatLng(
    15.2494,
    73.9458,
  );
  String currentStatus = "Normal";
  String deviceName = "Loading...";

  // Custom Location Data
  String floorInfo = "";
  String zoneInfo = "";
  String extraDetails = "";

  final TextEditingController _searchController =
      TextEditingController();

  // Loading flag
  bool _isLoading = true;

  final String _darkMapStyle = '''
    [{"elementType":"geometry","stylers":[{"color":"#212121"}]},{"elementType":"labels.icon","stylers":[{"visibility":"off"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},{"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#757575"}]},{"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},{"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},{"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#181818"}]},{"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},{"featureType":"poi.park","elementType":"labels.text.stroke","stylers":[{"color":"#1b1b1b"}]},{"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},{"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},{"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#373737"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},{"featureType":"road.highway.controlled_access","elementType":"geometry","stylers":[{"color":"#4e4e4e"}]},{"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},{"featureType":"transit","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},{"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3d3d3d"}]}]
  ''';

  @override
  void initState() {
    super.initState();
    _loadLocalSettings();

    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null && mounted) {
        setState(() {
          currentStatus =
              data['status'] ?? "Normal";
        });
      }
    });
  }

  Future<void> _loadLocalSettings() async {
    SharedPreferences prefs =
        await SharedPreferences.getInstance();
    setState(() {
      deviceName =
          prefs.getString('device_name') ??
          "Device not added yet";
      floorInfo =
          prefs.getString('loc_floor') ?? "";
      zoneInfo =
          prefs.getString('loc_zone') ?? "";
      extraDetails =
          prefs.getString('loc_details') ?? "";

      double? savedLat = prefs.getDouble(
        'map_lat',
      );
      double? savedLng = prefs.getDouble(
        'map_lng',
      );
      if (savedLat != null && savedLng != null) {
        _currentLocation = LatLng(
          savedLat,
          savedLng,
        );
      }

      // Tell the app we are ready to show the map!
      _isLoading = false;
    });
  }

  // --- THE REAL SEARCH LOGIC ---
  Future<void> _searchAndNavigate(
    String address,
  ) async {
    if (address.isEmpty) return;

    try {
      // Ask native mapping service for coordinates
      List<Location> locations =
          await locationFromAddress(address);
      if (locations.isNotEmpty) {
        LatLng newPos = LatLng(
          locations.first.latitude,
          locations.first.longitude,
        );

        // Fly camera to new location
        mapController.animateCamera(
          CameraUpdate.newLatLngZoom(
            newPos,
            18.0,
          ),
        );

        // Immediately open the details sheet to save it
        _showSetupBottomSheet(newPos);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text(
              '❌ Location not found. Try adding city/state.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- THE DATA ENTRY BOTTOM SHEET ---
  void _showSetupBottomSheet(LatLng newPosition) {
    TextEditingController floorController =
        TextEditingController(text: floorInfo);
    TextEditingController zoneController =
        TextEditingController(text: zoneInfo);
    TextEditingController detailsController =
        TextEditingController(text: extraDetails);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(
              context,
            ).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                "Set Camera Details",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              _buildTextField(
                zoneController,
                "Zone / Block",
                "e.g., BCA Block",
              ),
              const SizedBox(height: 10),
              _buildTextField(
                floorController,
                "Floor Number",
                "e.g., 2nd Floor Stairwell",
              ),
              const SizedBox(height: 10),
              _buildTextField(
                detailsController,
                "Specific Details",
                "e.g., Pointing towards canteen",
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                            10,
                          ),
                    ),
                  ),
                  onPressed: () async {
                    // Save locally
                    SharedPreferences prefs =
                        await SharedPreferences.getInstance();
                    await prefs.setDouble(
                      'map_lat',
                      newPosition.latitude,
                    );
                    await prefs.setDouble(
                      'map_lng',
                      newPosition.longitude,
                    );
                    await prefs.setString(
                      'loc_floor',
                      floorController.text,
                    );
                    await prefs.setString(
                      'loc_zone',
                      zoneController.text,
                    );
                    await prefs.setString(
                      'loc_details',
                      detailsController.text,
                    );

                    // Sync to Firebase (This is the magic that feeds Twilio!)
                    _dbRef
                        .child('location_details')
                        .update({
                          'latitude': newPosition
                              .latitude,
                          'longitude': newPosition
                              .longitude,
                          'floor': floorController
                              .text,
                          'zone':
                              zoneController.text,
                          'details':
                              detailsController
                                  .text,
                        });

                    // Update UI
                    setState(() {
                      _currentLocation =
                          newPosition;
                      floorInfo =
                          floorController.text;
                      zoneInfo =
                          zoneController.text;
                      extraDetails =
                          detailsController.text;
                    });

                    // THE FIX: Check if the specific context is mounted
                    if (!context.mounted) return;

                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '📍 Camera location secured & synced!',
                        ),
                        backgroundColor:
                            Colors.green,
                      ),
                    );
                  },
                  child: const Text(
                    "SAVE SETUP",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint,
  ) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey[400],
        ),
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.grey[600],
        ),
        filled: true,
        fillColor: Colors.grey[800],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void _onMapCreated(
    GoogleMapController controller,
  ) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    // Show a sleek loading screen for a split second until coordinates load
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.blueAccent,
          ),
        ),
      );
    }

    bool isAlert =
        (currentStatus == "CRITICAL RISK" ||
        currentStatus == "POTENTIAL FALL");

    String markerSnippet =
        "Status: $currentStatus";
    if (floorInfo.isNotEmpty ||
        zoneInfo.isNotEmpty) {
      markerSnippet +=
          "\nLoc: $zoneInfo, $floorInfo";
    }

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            // style: _darkMapStyle, // Uncomment if you want the dark map back!
            onLongPress: _showSetupBottomSheet,
            initialCameraPosition: CameraPosition(
              target: _currentLocation,
              zoom: 17.5,
            ),
            markers: {
              Marker(
                markerId: const MarkerId(
                  'zone_a',
                ),
                position: _currentLocation,
                infoWindow: InfoWindow(
                  title: deviceName.toUpperCase(),
                  snippet: markerSnippet,
                ),
                icon:
                    BitmapDescriptor.defaultMarkerWithHue(
                      isAlert
                          ? BitmapDescriptor
                                .hueRed
                          : BitmapDescriptor
                                .hueGreen,
                    ),
              ),
            },
          ),

          // --- THE FUNCTIONAL SEARCH BAR ---
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
              ),
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius:
                    BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(
                      127,
                    ),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller:
                          _searchController,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            "Search for location...",
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                        ),
                        border: InputBorder.none,
                      ),
                      textInputAction:
                          TextInputAction.search,
                      onSubmitted: (value) =>
                          _searchAndNavigate(
                            value,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.send,
                      color: Colors.blueAccent,
                    ),
                    onPressed: () =>
                        _searchAndNavigate(
                          _searchController.text,
                        ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Status Card
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius:
                    BorderRadius.circular(16),
                border: Border.all(
                  color: isAlert
                      ? Colors.red
                      : Colors.green,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(
                      127,
                    ),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          deviceName
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow
                              .ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Status: $currentStatus\n${zoneInfo.isEmpty ? 'Search or Long-press map to set location' : '$zoneInfo | $floorInfo'}",
                          style: TextStyle(
                            color:
                                Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isAlert
                        ? Icons.warning
                        : Icons.shield,
                    color: isAlert
                        ? Colors.red
                        : Colors.green,
                    size: 30,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
