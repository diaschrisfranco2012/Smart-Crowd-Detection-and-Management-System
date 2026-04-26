import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import 'home_page.dart';
import 'live_feed_page.dart';
import 'map_page.dart';
import 'settings_page.dart';

class MainNav extends StatefulWidget {
  const MainNav({super.key});

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _selectedIndex = 0;

  // The 4 screens we will switch between
  final List<Widget> _pages = [
    const HomePage(),
    const LiveFeedPage(),
    const MapPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        color: Colors.black,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 15.0,
            vertical: 20,
          ),
          child: GNav(
            backgroundColor: Colors.black,
            color: Colors.white,
            activeColor: Colors.white,
            tabBackgroundColor:
                Colors.grey.shade800,
            gap: 8,
            padding: const EdgeInsets.all(16),
            selectedIndex: _selectedIndex,
            onTabChange: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            tabs: const [
              GButton(
                icon: Icons.dashboard,
                text: 'Home',
              ),
              GButton(
                icon: Icons.camera_alt,
                text: 'Feed',
              ),
              GButton(
                icon: Icons.map,
                text: 'Map',
              ),
              GButton(
                icon: Icons.settings,
                text: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
