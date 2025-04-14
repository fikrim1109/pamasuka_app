// File: lib/menu_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import untuk SystemUiOverlayStyle jika diperlukan
import 'package:pamasuka/akunpage.dart'; // <-- Import for Account Page is correct
import 'package:pamasuka/login_page.dart'; // <-- Import for Login Page is correct

// --- IMPORTANT: Ensure these paths correctly point to your ACTUAL page files ---
import 'package:pamasuka/home_page.dart'; // <-- Should import the REAL HomePage
import 'package:pamasuka/rumah_page.dart'; // <-- Should import the REAL RumahPage
// --- ---

// --- Definisikan Rentang ID User Normal (sesuai PHP) ---
const int MIN_NORMAL_USER_ID_RANGE = 6;
const int MAX_NORMAL_USER_ID_RANGE = 784;
// --- ---

class MenuPage extends StatelessWidget {
  final String username;
  final int userId;

  const MenuPage({Key? key, required this.username, required this.userId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Samalonian APP',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
        elevation: 2,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        automaticallyImplyLeading: false,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'images/Samalonian APP.png',
                height: 180,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  print("Error loading menu logo: $error");
                  return const Icon(Icons.broken_image, size: 100, color: Colors.grey);
                },
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Selamat datang,\n$username!',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B3A3A),
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        blurRadius: 6.0,
                        color: Colors.black38,
                        offset: Offset(1.5, 1.5),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Pilih menu di bawah untuk melanjutkan',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF3B3A3A),
                    fontWeight: FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Material(
        elevation: 10,
        color: Colors.white,
        child: BottomNavBar(username: username, userId: userId),
      ),
    );
  }
}

// --- Bottom Navigation Bar Widget ---
class BottomNavBar extends StatelessWidget {
  final String username;
  final int userId;

  const BottomNavBar({Key? key, required this.username, required this.userId})
      : super(key: key);

  // --- Helper function to show access denied dialog ---
  void _showAccessDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Akses Ditolak'),
          ],
        ),
        content: const Text('Anda tidak memiliki izin untuk mengakses halaman ini.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  // --- ---

  @override
  Widget build(BuildContext context) {
    // --- Determine User Type Based on ID Range ---
    final bool isNormalUser = (userId >= MIN_NORMAL_USER_ID_RANGE && userId <= MAX_NORMAL_USER_ID_RANGE);
    // --- ---

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          // --- Navigation Item: Outlet PJP (HomePage) ---
          _NavBarItem(
            icon: Icons.store_mall_directory_outlined,
            label: 'Outlet PJP',
            onTap: () {
              // Access Logic: Allow ONLY if user is WITHIN the normal range [6, 784]
              if (isNormalUser) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomePage(username: username, userId: userId),
                  ),
                );
              } else {
                // Show access denied for users outside the normal range
                _showAccessDeniedDialog(context);
              }
            },
          ),

          // --- Navigation Item: Outlet Non PJP (RumahPage) ---
          _NavBarItem(
            icon: Icons.home_work_outlined,
            label: 'Outlet Non PJP',
            onTap: () {
              // Access Logic: Allow ONLY if user is OUTSIDE the normal range [6, 784]
              if (!isNormalUser) {
                 Navigator.push(
                   context,
                   MaterialPageRoute(
                     builder: (context) => RumahPage(username: username, userId: userId),
                   ),
                 );
              } else {
                // Show access denied for users within the normal range
                _showAccessDeniedDialog(context);
              }
            },
          ),

          // --- Navigation Item: Akun (AkunPage) ---
          _NavBarItem(
            icon: Icons.account_circle_outlined,
            label: 'Akun',
            onTap: () {
              // Access Logic: ALL users can access Account page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AkunPage(
                    userId: userId,
                    username: username,
                  ),
                ),
              );
            },
          ),

          // --- Navigation Item: Logout ---
          _NavBarItem(
            icon: Icons.logout,
            label: 'Logout',
            onTap: () {
              // Access Logic: ALL users can logout
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Text('Konfirmasi Logout'),
                  content: const Text('Apakah Anda yakin ingin keluar?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginPage()),
                          (route) => false,
                        );
                      },
                      child: const Text('Logout', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// --- Reusable Bottom Navigation Bar Item Widget ---
// (No changes needed here)
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
        splashColor: Colors.red.withOpacity(0.1),
        highlightColor: Colors.red.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: Colors.redAccent,
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------- IMPORTANT ------------------
// Ensure 'home_page.dart' and 'rumah_page.dart' exist and are correctly imported.
// ------------------------------------------