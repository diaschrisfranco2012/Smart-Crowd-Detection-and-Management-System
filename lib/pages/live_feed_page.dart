import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_page.dart'; // Ensure this matches your file name

class LiveFeedPage extends StatefulWidget {
  const LiveFeedPage({super.key});
  @override
  State<LiveFeedPage> createState() =>
      _LiveFeedPageState();
}

class _LiveFeedPageState
    extends State<LiveFeedPage> {
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref(
        'crowd_monitor/zone_A',
      );

  bool showDetails = false;
  String cameraName = "Loading...";
  String streamUrl = "";

  int currentCount = 0;
  String riskLevel = "SAFE";
  Color riskColor = Colors.green;

  bool isHighAlert = false;
  String latestLogKey = "";

  List<FlSpot> chartData = [];
  List<Map<dynamic, dynamic>> pastLogs = [];

  @override
  void initState() {
    super.initState();
    _loadCameraName();

    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null && mounted) {
        setState(() {
          currentCount = data['live_count'] ?? 0;
          String status =
              data['status'] ?? "Normal";

          // --- 1. THE LATCH & RISK STATUS LOGIC ---
          if (status == "CRITICAL RISK" ||
              status == "MANUAL EMERGENCY") {
            riskLevel = "DANGER";
            riskColor = Colors.redAccent;
            isHighAlert =
                true; // The Latch: It stays true until user slides an action
          } else if (status == "High Density") {
            riskLevel = "WARNING";
            riskColor = Colors.orange;
          } else {
            riskLevel = "SAFE";
            riskColor = Colors.green;
          }

          // Parse the history node
          if (data['history'] != null) {
            Map<dynamic, dynamic> historyMap =
                data['history'];
            List<MapEntry<dynamic, dynamic>>
            entries = historyMap.entries.toList();

            entries.sort(
              (a, b) =>
                  (b.value['timestamp'] ?? 0)
                      .compareTo(
                        a.value['timestamp'] ?? 0,
                      ),
            );

            if (entries.isNotEmpty) {
              latestLogKey = entries.first.key
                  .toString();
            }

            pastLogs = entries
                .map(
                  (e) =>
                      Map<dynamic, dynamic>.from(
                        e.value as Map,
                      ),
                )
                .toList();

            chartData.clear();
            double xIndex = 0;
            for (var log in pastLogs.reversed) {
              double peopleCount =
                  (log['people_count'] ?? 0)
                      .toDouble();
              chartData.add(
                FlSpot(xIndex, peopleCount),
              );
              xIndex++;
            }
          }

          if (chartData.isEmpty) {
            chartData = [const FlSpot(0, 0)];
          }
        });
      }
    });
  }

  Future<void> _loadCameraName() async {
    SharedPreferences prefs =
        await SharedPreferences.getInstance();
    setState(() {
      cameraName =
          prefs.getString('device_name') ??
          "Device not added yet";
      streamUrl =
          prefs.getString('network_config') ?? "";
    });
  }

  // --- THE REMOTE KILL SWITCH ---
  void _handleAlarm(bool isTrueAlarm) {
    String alarmType = isTrueAlarm
        ? "True"
        : "False";

    if (latestLogKey.isNotEmpty) {
      _dbRef
          .child('history')
          .child(latestLogKey)
          .update({'type': alarmType});
    }

    _dbRef.update({
      'status': 'Normal',
      'false_alarm_flag': !isTrueAlarm,
    });

    setState(() {
      isHighAlert =
          false; // Turn off the latch after they slide
    });
  }

  void _toggleFullscreen() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: streamUrl.isNotEmpty
                  ? Mjpeg(
                      isLive: true,
                      stream: streamUrl,
                      fit: BoxFit.contain,
                    )
                  : const Center(
                      child: Icon(
                        Icons.videocam_off,
                        color: Colors.grey,
                        size: 100,
                      ),
                    ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(
                  Icons.fullscreen_exit,
                  color: Colors.white,
                  size: 30,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 10,
                    ),
                  ],
                ),
                onPressed: () =>
                    Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
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
                  const Text(
                    "Live Camera Feed",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
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
              const SizedBox(height: 20),

              Center(
                child: Text(
                  cameraName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // --- 2. THE RISK UI ---
              Center(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 8,
                          ),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius:
                            BorderRadius.circular(
                              20,
                            ),
                      ),
                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.people,
                            color:
                                Colors.blueAccent,
                            size: 20,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Text(
                            "Headcount: $currentCount",
                            style:
                                const TextStyle(
                                  color: Colors
                                      .white,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 8,
                          ),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(
                          alpha: 0.15,
                        ), // Updated to withValues
                        borderRadius:
                            BorderRadius.circular(
                              20,
                            ),
                        border: Border.all(
                          color: riskColor,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Icon(
                            riskLevel == "SAFE"
                                ? Icons
                                      .verified_user
                                : Icons
                                      .warning_amber_rounded,
                            color: riskColor,
                            size: 20,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Text(
                            "Risk: $riskLevel",
                            style: TextStyle(
                              color: riskColor,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              // Video Feed Box
              Container(
                height: 220,
                width: double.infinity,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius:
                      BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.grey[800]!,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (streamUrl.isNotEmpty)
                      Mjpeg(
                        isLive: true,
                        error:
                            (
                              context,
                              error,
                              stack,
                            ) => const Center(
                              child: Text(
                                "Camera Offline or Loading...",
                                style: TextStyle(
                                  color:
                                      Colors.red,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ),
                        stream: streamUrl,
                      )
                    else
                      const Center(
                        child: Text(
                          "Go to Settings to add Network URL",
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: _toggleFullscreen,
                        child: const Icon(
                          Icons.fullscreen,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Incident Report Card
              AnimatedContainer(
                duration: const Duration(
                  milliseconds: 300,
                ),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Incidents Reported",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SingleChildScrollView(
                      scrollDirection:
                          Axis.horizontal,
                      child: SizedBox(
                        height: 120,
                        width:
                            chartData.length > 5
                            ? chartData.length *
                                  50.0
                            : MediaQuery.of(
                                    context,
                                  ).size.width -
                                  80,
                        child: LineChart(
                          LineChartData(
                            gridData:
                                const FlGridData(
                                  show: true,
                                  drawVerticalLine:
                                      false,
                                ),
                            titlesData: FlTitlesData(
                              leftTitles:
                                  const AxisTitles(
                                    sideTitles:
                                        SideTitles(
                                          showTitles:
                                              false,
                                        ),
                                  ),
                              topTitles:
                                  const AxisTitles(
                                    sideTitles:
                                        SideTitles(
                                          showTitles:
                                              false,
                                        ),
                                  ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles:
                                      true,
                                  reservedSize:
                                      40,
                                  getTitlesWidget:
                                      (
                                        value,
                                        meta,
                                      ) => Text(
                                        "${value.toInt()}",
                                        style: const TextStyle(
                                          color: Colors
                                              .grey,
                                          fontSize:
                                              10,
                                        ),
                                      ),
                                ),
                              ),
                              bottomTitles:
                                  const AxisTitles(
                                    sideTitles:
                                        SideTitles(
                                          showTitles:
                                              false,
                                        ),
                                  ),
                            ),
                            borderData:
                                FlBorderData(
                                  show: false,
                                ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: chartData,
                                isCurved: true,
                                color: Colors
                                    .blueAccent,
                                barWidth: 2,
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors
                                      .green
                                      .withValues(
                                        alpha:
                                            0.3,
                                      ),
                                ), // Updated to withValues
                                dotData:
                                    const FlDotData(
                                      show: true,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .spaceAround,
                      children: [
                        _buildLegendItem(
                          Colors.green,
                          "Low Chance",
                        ),
                        _buildLegendItem(
                          Colors.orange,
                          "High Chance",
                        ),
                        _buildLegendItem(
                          Colors.red,
                          "Critical Chance",
                        ),
                      ],
                    ),
                    if (showDetails) ...[
                      const Divider(
                        color: Colors.grey,
                        height: 30,
                      ),
                      const Text(
                        "Past Logs",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (pastLogs.isEmpty)
                        const Text(
                          "No incidents recorded yet.",
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ...pastLogs.map((log) {
                        int ts =
                            log['timestamp'] ?? 0;
                        DateTime date =
                            DateTime.fromMillisecondsSinceEpoch(
                              ts,
                            );
                        String formattedDate =
                            "${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
                        return _buildLogEntry(
                          formattedDate,
                          log['description'] ??
                              "Alert Triggered",
                          log['type'] ??
                              "Pending",
                        );
                      }),
                    ],
                    const SizedBox(height: 15),
                    GestureDetector(
                      onTap: () => setState(
                        () => showDetails =
                            !showDetails,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius:
                              BorderRadius.circular(
                                10,
                              ),
                        ),
                        child: Center(
                          child: Text(
                            showDetails
                                ? "Less Details"
                                : "More Details",
                            style:
                                const TextStyle(
                                  color: Colors
                                      .white,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- 3. THE SWIPE-TO-ACTION AREA ---
              if (isHighAlert)
                Column(
                  children: [
                    _buildSwipeAction(
                      title:
                          "Slide right to Confirm Stampede",
                      color: Colors.redAccent,
                      icon: Icons.warning_rounded,
                      isConfirm: true,
                    ),
                    const SizedBox(height: 15),
                    _buildSwipeAction(
                      title:
                          "Slide right to mark False Alarm",
                      color: Colors.blueGrey,
                      icon: Icons.shield,
                      isConfirm: false,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(
    Color color,
    String label,
  ) {
    return Row(
      children: [
        CircleAvatar(
          radius: 4,
          backgroundColor: color,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildLogEntry(
    String date,
    String desc,
    String type,
  ) {
    Color typeColor = Colors.yellow;
    if (type == "True") {
      typeColor = Colors.redAccent;
    }
    if (type == "False") {
      typeColor = Colors.orange;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              date,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10.0,
              ),
              child: Text(
                desc,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Text(
            type,
            style: TextStyle(
              color: typeColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // --- CUSTOM SWIPE WIDGET ---
  Widget _buildSwipeAction({
    required String title,
    required Color color,
    required IconData icon,
    required bool isConfirm,
  }) {
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.startToEnd,
      onDismissed: (direction) {
        _handleAlarm(isConfirm);
      },
      background: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(
          Icons.check_circle_outline,
          color: Colors.white,
          size: 30,
        ),
      ),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: color.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(
              width: 60,
            ), // Keeps text centered
          ],
        ),
      ),
    );
  }
}
