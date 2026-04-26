import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() =>
      _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String cameraName = "Device not added yet";
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref(
        'crowd_monitor/zone_A',
      );

  int currentCount = 0;
  int lastAlertTimestamp = 0;
  bool isPiOnline = false;

  // --- REAL STORAGE & STATUS VARIABLES ---
  double storageUsed = 0.0;
  double totalStorage =
      16.0; // Starts at 16, but Pi will instantly overwrite this
  String currentStatus = "Normal";

  Timer? _minuteTimer;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          cameraName =
              prefs.getString('device_name') ??
              "Device not added yet";
        });
      }
    });

    // 1. Listen to Firebase
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null && mounted) {
        setState(() {
          currentCount = data['live_count'] ?? 0;
          isPiOnline =
              data['pi_is_online'] ?? false;
          lastAlertTimestamp =
              data['last_alert_timestamp'] ?? 0;

          // Grabbing the SMART status from the Pi
          currentStatus =
              data['status'] ?? "Normal";

          // Grabbing the REAL storage numbers
          if (data['pi_storage_used'] != null) {
            storageUsed =
                (data['pi_storage_used'])
                    .toDouble();
          }
          if (data['pi_storage_total'] != null) {
            totalStorage =
                (data['pi_storage_total'])
                    .toDouble();
          }
        });
      }
    });

    // 2. Start a timer that rebuilds the UI every 60 seconds
    _minuteTimer = Timer.periodic(
      const Duration(seconds: 60),
      (timer) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    super.dispose();
  }

  // --- THE CALCULATOR FUNCTION ---
  String _calculateTimeSince(int timestamp) {
    if (timestamp == 0) {
      return "Waiting for data...";
    }

    final now = DateTime.now();
    final alertTime =
        DateTime.fromMillisecondsSinceEpoch(
          timestamp,
        );
    final difference = now.difference(alertTime);

    if (difference.inDays > 0) {
      return "${difference.inDays}d ${difference.inHours % 24}h ago";
    } else if (difference.inHours > 0) {
      return "${difference.inHours}h ${difference.inMinutes % 60}m ago";
    } else if (difference.inMinutes > 0) {
      return "${difference.inMinutes}m ago";
    } else {
      return "Just now";
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- SMART STATUS UI LOGIC ---
    Color statusColor = const Color(
      0xFF4CAF50,
    ); // Green
    IconData statusIcon =
        Icons.check_circle_outline;
    String statusText = "Normal";

    // The app reacts exactly to what the Pi's AI decides!
    if (currentStatus == "CRITICAL RISK") {
      statusColor = const Color(
        0xFFE53935,
      ); // Red
      statusIcon = Icons.warning_amber_rounded;
      statusText = "Critical";
    } else if (currentStatus ==
        "POTENTIAL FALL") {
      statusColor = const Color(
        0xFFE53935,
      ); // Red
      statusIcon = Icons
          .personal_injury; // Perfect icon for a fall
      statusText = "Fall Alert";
    } else if (currentStatus == "High Density") {
      statusColor = const Color(
        0xFFFB8C00,
      ); // Orange
      statusIcon = Icons.groups;
      statusText = "Dense";
    }

    String userName =
        FirebaseAuth
            .instance
            .currentUser
            ?.displayName ??
        "Chris Dias";

    String timeSinceAlertString =
        _calculateTimeSince(lastAlertTimestamp);

    return Scaffold(
      backgroundColor: const Color(
        0xFF121212,
      ), // Keep it dark and sleek
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome Back,",
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const ProfilePage(),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      backgroundColor:
                          Colors.grey[800],
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Big Live Count Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Align(
                      alignment:
                          Alignment.topRight,
                      child: Icon(
                        Icons.people_alt,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      "$currentCount",
                      style: const TextStyle(
                        fontSize: 80,
                        fontWeight:
                            FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "Live Count in $cameraName",
                      style: const TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2x2 Grid for Stats
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
                children: [
                  // 1. Status Box (Now incredibly smart!)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          statusColor.withAlpha(
                            204,
                          ),
                          statusColor,
                        ],
                        begin: Alignment.topLeft,
                        end:
                            Alignment.bottomRight,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                            20,
                          ),
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      children: [
                        Icon(
                          statusIcon,
                          color: Colors.white,
                          size: 50,
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        Text(
                          statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Time Since Last Alert
                  Container(
                    padding: const EdgeInsets.all(
                      20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius:
                          BorderRadius.circular(
                            20,
                          ),
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          "Time Since\nLast Alert",
                          style: TextStyle(
                            color:
                                Colors.grey[400],
                          ),
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(
                              width: 5,
                            ),
                            Expanded(
                              child: Text(
                                timeSinceAlertString,
                                style: const TextStyle(
                                  color: Colors
                                      .white,
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 3. Pi Storage Box (Now dynamically scaling!)
                  Container(
                    padding: const EdgeInsets.all(
                      20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius:
                          BorderRadius.circular(
                            20,
                          ),
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          "${storageUsed.toStringAsFixed(2)} GB",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        LinearProgressIndicator(
                          value:
                              (storageUsed /
                                      totalStorage)
                                  .clamp(
                                    0.0,
                                    1.0,
                                  ),
                          backgroundColor:
                              Colors.grey[800],
                          color:
                              Colors.blueAccent,
                          borderRadius:
                              BorderRadius.circular(
                                5,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "${storageUsed.toStringAsFixed(2)} GB / ${totalStorage.toInt()}GB",
                          style: TextStyle(
                            color:
                                Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "PI Storage",
                          style: TextStyle(
                            color:
                                Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 4. PI Status Box
                  Container(
                    padding: const EdgeInsets.all(
                      20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius:
                          BorderRadius.circular(
                            20,
                          ),
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      children: [
                        Icon(
                          isPiOnline
                              ? Icons.wifi
                              : Icons.wifi_off,
                          color: isPiOnline
                              ? Colors.green
                              : Colors.redAccent,
                          size: 50,
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        Text(
                          isPiOnline
                              ? "PI Online"
                              : "PI Offline",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
