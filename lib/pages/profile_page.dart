import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() =>
      _ProfilePageState();
}

class _ProfilePageState
    extends State<ProfilePage> {
  final User? currentUser =
      FirebaseAuth.instance.currentUser;

  final TextEditingController
  _usernameController = TextEditingController();
  final TextEditingController _emailController =
      TextEditingController();
  final TextEditingController
  _passwordController = TextEditingController();

  bool isEditing = false;
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Pre-fill the fields with the logged-in user's data
    _usernameController.text =
        currentUser?.displayName ?? "Chris Dias";
    _emailController.text =
        currentUser?.email ??
        "chrisdias.216@gmail.com";
    _passwordController.text =
        "********"; // We don't fetch real passwords for security
  }

  Future<void> _toggleEditSave() async {
    if (isEditing) {
      // Logic to SAVE the data
      try {
        if (currentUser != null &&
            _usernameController.text.isNotEmpty) {
          await currentUser!.updateDisplayName(
            _usernameController.text,
          );
          // Note: Updating email or password requires re-authentication in Firebase,
          // so we'll just update the display name for this hackathon demo.
        }

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            const SnackBar(
              content: Text('✅ Profile Updated!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        debugPrint("Error updating profile: $e");
      }
    }

    // Toggle the state
    setState(() {
      isEditing = !isEditing;
    });
  }

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
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 20.0,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                "PROFILE",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),

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
                    _buildLabel("USERNAME"),
                    _buildTextField(
                      _usernameController,
                      false,
                    ),
                    const SizedBox(height: 20),

                    _buildLabel("EMAIL"),
                    _buildTextField(
                      _emailController,
                      false,
                    ),
                    const SizedBox(height: 20),

                    _buildLabel("PASSWORD"),
                    _buildTextField(
                      _passwordController,
                      true,
                    ),
                    const SizedBox(height: 30),

                    // Dynamic EDIT / SAVE Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed:
                            _toggleEditSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isEditing
                              ? const Color(
                                  0xFF4CAF50,
                                )
                              : Colors
                                    .black, // Green for Save, Black for Edit
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                                  10,
                                ),
                            side: BorderSide(
                              color: isEditing
                                  ? Colors
                                        .transparent
                                  : Colors
                                        .grey[800]!,
                            ),
                          ),
                        ),
                        icon: Icon(
                          isEditing
                              ? Icons.save
                              : Icons.edit,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: Text(
                          isEditing
                              ? "SAVE CHANGES"
                              : "EDIT",
                          style: const TextStyle(
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

  // Helper widget for field labels
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  // Helper widget for text fields
  Widget _buildTextField(
    TextEditingController controller,
    bool isPassword,
  ) {
    return TextField(
      controller: controller,
      enabled:
          isEditing, // Unlocks when EDIT is pressed
      obscureText: isPassword
          ? obscurePassword
          : false,
      style: TextStyle(
        color: isEditing
            ? Colors.white
            : Colors.grey[500],
      ),
      decoration: InputDecoration(
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
        // Add the eye icon toggle for the password field
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: Colors.grey[500],
                ),
                onPressed: () {
                  setState(() {
                    obscurePassword =
                        !obscurePassword;
                  });
                },
              )
            : Icon(
                Icons.visibility,
                color: Colors.grey[700],
              ), // Static icon for others like your mockup
      ),
    );
  }
}
