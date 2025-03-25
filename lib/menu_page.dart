import 'package:flutter/material.dart';
import 'package:pamasuka/rumah_page.dart';
import 'home_page.dart';
import 'login_page.dart';

class MenuPage extends StatelessWidget {
  final String username;
  final int userId;
  const MenuPage({Key? key, required this.username, required this.userId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar for consistency and branding
      appBar: AppBar(
        title: const Text(
          'Samalonian APP',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 2,
      ),
      // Body with gradient background matching LoginPage
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFB6B6), 
              Color(0xFFFF8E8E), 
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo/image
              Image.asset(
                'images/Samalonian APP.png',
                height: 180, // Slightly smaller for better balance
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24), // Spacing for breathing room
              // Welcome message with modern typography
              Text(
                'Selamat datang, $username!',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3B3A3A),
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      blurRadius: 8.0,
                      color: Colors.black26,
                      offset: Offset(2.0, 2.0),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Optional subtitle for clarity
              const Text(
                'Pilih menu di bawah untuk melanjutkan',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF3B3A3A),
                  fontWeight: FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      // Bottom navigation bar with elevation
      bottomNavigationBar: Material(
        elevation: 10, // Adds a modern floating effect
        child: BottomNavBar(username: username, userId: userId),
      ),
    );
  }
}

class BottomNavBar extends StatelessWidget {
  final String username;
  final int userId;

  const BottomNavBar({Key? key, required this.username, required this.userId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavBarItem(
            icon: Icons.store,
            label: 'Outlet PJP',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HomePage(username: username, userId: userId),
                ),
              );
            },
          ),
          _NavBarItem(
            icon: Icons.home,
            label: 'Outlet Non PJP',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RumahPage(username: username, userId: userId),
                ),
              );
            },
          ),
          _NavBarItem(
            icon: Icons.logout,
            label: 'Logout',
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavBarItem({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.grey.withOpacity(0.2),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: const Color(0xFFC0392B), // Matches the red theme
                size: 28, // Larger icons for modern feel
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}