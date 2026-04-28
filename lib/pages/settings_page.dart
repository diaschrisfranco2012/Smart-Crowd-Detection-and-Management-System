import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/login_page.dart';
import 'profile_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() =>
      _SettingsPageState();
}

class _SettingsPageState
    extends State<SettingsPage> {
  final TextEditingController _networkController =
      TextEditingController();
  final TextEditingController
  _deviceNameController = TextEditingController();

  // CONTROLLERS FOR AI LIMITS
  final TextEditingController _warningController =
      TextEditingController();
  final TextEditingController
  _criticalController = TextEditingController();
  final TextEditingController _densityController =
      TextEditingController();
  final TextEditingController
  _confidenceController =
      TextEditingController(); // NEW CONFIDENCE CONTROLLER

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load existing settings when the page opens
  Future<void> _loadSettings() async {
    SharedPreferences prefs =
        await SharedPreferences.getInstance();
    setState(() {
      _networkController.text =
          prefs.getString('network_config') ?? '';
      _deviceNameController.text =
          prefs.getString('device_name') ??
          'ZONE A - STAIRWAYS';
    });

    // Fetch existing AI limits from Firebase so the app always shows current math
    DatabaseReference settingsRef =
        FirebaseDatabase.instance.ref(
          'crowd_monitor/zone_A/settings',
        );
    settingsRef.once().then((
      DatabaseEvent event,
    ) {
      if (event.snapshot.exists) {
        final data =
            event.snapshot.value
                as Map<dynamic, dynamic>;
        setState(() {
          _warningController.text =
              data['warning_limit']?.toString() ??
              '30';
          _criticalController.text =
              data['critical_limit']
                  ?.toString() ??
              '50';
          _densityController.text =
              data['density_limit']?.toString() ??
              '15';
          _confidenceController.text =
              data['ai_confidence']?.toString() ??
              '0.15'; // LOAD CONFIDENCE
        });
      } else {
        // Defaults if Firebase is empty
        _warningController.text = '30';
        _criticalController.text = '50';
        _densityController.text = '15';
        _confidenceController.text =
            '0.15'; // DEFAULT CONFIDENCE
      }
    });
  }

  // Save settings when the blue button is pressed
  Future<void> _saveConfiguration() async {
    SharedPreferences prefs =
        await SharedPreferences.getInstance();
    await prefs.setString(
      'network_config',
      _networkController.text,
    );
    await prefs.setString(
      'device_name',
      _deviceNameController.text,
    );

    // PUSH NEW LIMITS TO FIREBASE TO UPDATE THE PI INSTANTLY
    DatabaseReference settingsRef =
        FirebaseDatabase.instance.ref(
          'crowd_monitor/zone_A/settings',
        );
    await settingsRef.set({
      'warning_limit':
          int.tryParse(_warningController.text) ??
          30,
      'critical_limit':
          int.tryParse(
            _criticalController.text,
          ) ??
          50,
      'density_limit':
          int.tryParse(_densityController.text) ??
          15,
      'ai_confidence':
          double.tryParse(
            _confidenceController.text,
          ) ??
          0.15, // SAVE CONFIDENCE AS DOUBLE
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ AI Configuration Saved Successfully!',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Handle Firebase Logout
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _networkController.dispose();
    _deviceNameController.dispose();
    _warningController.dispose();
    _criticalController.dispose();
    _densityController.dispose();
    _confidenceController
        .dispose(); // DISPOSE NEW CONTROLLER
    super.dispose();
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
                    "Control Panel",
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
              const SizedBox(height: 30),

              // Settings Form Container
              Container(
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
                    _buildLabel("NETWORK CONFIG"),
                    _buildTextField(
                      _networkController,
                      "Enter Network IP or URL",
                    ),
                    const SizedBox(height: 20),

                    _buildLabel("DEVICE NAME"),
                    _buildTextField(
                      _deviceNameController,
                      "e.g. Stairways Camera A",
                    ),
                    const SizedBox(height: 20),

                    const Divider(
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 10),

                    const Text(
                      "AI CALIBRATION LIMITS",
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 14,
                        fontWeight:
                            FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // AI SETTINGS WITH TOOLTIPS
                    _buildLabel(
                      "WARNING HEADCOUNT LIMIT",
                      tooltipMessage:
                          "The max number of people allowed before the system turns yellow and warns of high capacity. (Default: 30)",
                    ),
                    _buildTextField(
                      _warningController,
                      "e.g. 30",
                      isNumber: true,
                    ),
                    const SizedBox(height: 20),

                    _buildLabel(
                      "CRITICAL HEADCOUNT LIMIT (ALARM)",
                      tooltipMessage:
                          "The absolute maximum room capacity. Exceeding this triggers the physical siren and SMS alert. (Default: 50)",
                    ),
                    _buildTextField(
                      _criticalController,
                      "e.g. 50",
                      isNumber: true,
                    ),
                    const SizedBox(height: 20),

                    _buildLabel(
                      "DENSITY STAMPEDE LIMIT (ALARM)",
                      tooltipMessage:
                          "The number of people dangerously squished together in tight clusters. Triggers the stampede alarm even if the room isn't full! (Default: 15)",
                    ),
                    _buildTextField(
                      _densityController,
                      "e.g. 15",
                      isNumber: true,
                    ),
                    const SizedBox(height: 20),

                    // NEW CONFIDENCE INPUT
                    _buildLabel(
                      "AI CONFIDENCE THRESHOLD",
                      tooltipMessage:
                          "Adjust AI sensitivity. Lower (e.g. 0.10) detects more but may cause false positives. Higher (e.g. 0.30) is stricter. (Default: 0.15)",
                    ),
                    _buildTextField(
                      _confidenceController,
                      "e.g. 0.15",
                      isNumber: true,
                    ),
                    const SizedBox(height: 30),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed:
                            _saveConfiguration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(
                                0xFF4C8DFF,
                              ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                                  10,
                                ),
                          ),
                        ),
                        child: const Text(
                          "SAVE CONFIGURATION",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight:
                                FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Colors.red,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                            10,
                          ),
                    ),
                  ),
                  child: const Text(
                    "LOGOUT",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget for field labels with optional tooltips
  Widget _buildLabel(
    String text, {
    String? tooltipMessage,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          if (tooltipMessage != null) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: tooltipMessage,
              triggerMode: TooltipTriggerMode.tap,
              showDuration: const Duration(
                seconds: 4,
              ),
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius:
                    BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blueAccent,
                ),
              ),
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.4,
              ),
              child: const Icon(
                Icons.info_outline,
                color: Colors.grey,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper widget for text fields (Upgraded to support decimal numbers)
  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      // UPDATED: Allows decimal points on the mobile number keyboard!
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(
              decimal: true,
            )
          : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
        ),
        filled: true,
        fillColor: Colors.grey[800],
        contentPadding:
            const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 15,
            ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
