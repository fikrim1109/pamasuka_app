// File: lib/menu_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Corrected import path if needed, ensure case sensitivity matches file name
import 'package:pamasuka/Laporan_Penjualan.dart'; // Corrected import
import 'package:pamasuka/akunpage.dart';       // Verify path
import 'package:pamasuka/login_page.dart';     // Verify path

// --- IMPORTANT: Verify these paths match your actual file locations ---
// If these files/paths are incorrect, navigation will fail.
import 'package:pamasuka/home_page.dart';      // <-- VERIFY THIS PATH (Used for Outlet PJP)
import 'package:pamasuka/rumah_page.dart';     // <-- VERIFY THIS PATH (Used for Outlet Non PJP)
import 'package:pamasuka/performapage.dart';   // <-- VERIFY THIS PATH
// --- ---

// --- User ID Range Definition ---
// IMPROVEMENT: Consider moving these to a dedicated config file (e.g., lib/config/user_roles.dart)
// or ideally, have the API return a user 'role' string instead of relying on ID ranges.
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
    // Determine User Type Based on ID Range (calculated once)
    final bool isNormalUser = (userId >= MIN_NORMAL_USER_ID_RANGE && userId <= MAX_NORMAL_USER_ID_RANGE);

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
              const Spacer(), // Push content down from AppBar

              // IMPROVEMENT: Added comment recommending asset constants
              Image.asset(
                'images/Samalonian_app.png', // Ensure path is correct and in pubspec.yaml
                height: MediaQuery.of(context).size.height * 0.22,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  print("Error loading menu logo: $error");
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         Icon(Icons.broken_image_outlined, size: 80, color: Colors.grey),
                         SizedBox(height: 8),
                         Text("Logo Gagal Dimuat", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24), // Space between image and text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Selamat datang,\n$username!',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B3A3A),
                    letterSpacing: 0.5,
                    height: 1.3,
                    shadows: [
                      Shadow(
                        blurRadius: 4.0,
                        color: Colors.black26,
                        offset: Offset(1.0, 1.0),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16), // Space between welcome text and instruction
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 30.0),
                child: Text(
                  'Pilih menu di bawah untuk melanjutkan',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF555555),
                    fontWeight: FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const Spacer(), // Push content up from BottomNavBar
            ],
          ),
        ),
      ),
      // --- UPDATED Bottom Navigation Bar ---
      bottomNavigationBar: Material(
        elevation: 10,
        color: Colors.white,
        child: BottomNavBar(username: username, userId: userId, isNormalUser: isNormalUser),
      ),
    );
  }
}

// --- UPDATED Bottom Navigation Bar Widget ---
class BottomNavBar extends StatelessWidget {
  final String username;
  final int userId;
  final bool isNormalUser; // Receive pre-calculated user type

  const BottomNavBar({
    Key? key,
    required this.username,
    required this.userId,
    required this.isNormalUser,
  }) : super(key: key);

  // --- Helper function to show access denied dialog (Unchanged) ---
  void _showAccessDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Akses Ditolak', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Anda tidak memiliki izin untuk mengakses halaman ini.'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      ),
    );
  }
  // --- ---

  // --- Helper function for Logout Dialog (Unchanged) ---
   void _showLogoutConfirmationDialog(BuildContext context) {
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
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
       ),
     );
   }
   // --- ---

  // --- NEW Helper function to show Laporan options ---
  void _showLaporanOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder( // Add rounded corners
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (BuildContext bc) {
        return SafeArea( // Ensure content is not obstructed by system UI
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap( // Use Wrap for simple vertical list
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    'Pilih Jenis Laporan',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.store_mall_directory, color: Colors.redAccent),
                  title: const Text('Outlet PJP'),
                  onTap: () {
                    Navigator.pop(context); // Close the bottom sheet first
                    if (!isNormalUser) {
                      _showAccessDeniedDialog(context);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HomePage(username: username, userId: userId),
                        ),
                      );
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.home_work, color: Colors.redAccent),
                  title: const Text('Outlet Non PJP'),
                  onTap: () {
                    Navigator.pop(context); // Close the bottom sheet first
                    if (isNormalUser) {
                      _showAccessDeniedDialog(context);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RumahPage(username: username, userId: userId),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  // --- ---

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
      child: SafeArea(
        bottom: true,
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [

            // --- Navigation Item: Laporan (Shows Bottom Sheet) ---
            _NavBarItem(
              icon: Icons.description_outlined, // Changed icon
              label: 'Laporan',
              onTap: () {
                _showLaporanOptions(context); // Call the helper to show options
              },
            ),

            // --- Navigation Item: Penjualan ---
            _NavBarItem(
              icon: Icons.point_of_sale_outlined, // New icon
              label: 'Penjualan',
              onTap: () {
                // **ACCESS CONTROL:** Assuming only NORMAL users can access Penjualan
                if (!isNormalUser) {
                  _showAccessDeniedDialog(context);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    // *** FIXED: Added the required 'outletType' parameter ***
                    // Assuming 'PJP' is the correct type for normal users accessing sales reports.
                    // Adjust 'PJP' if your LaporanPenjualan expects a different value or enum.
                    builder: (context) => LaporanPenjualan(
                      username: username,
                      userId: userId,
                      outletType: 'PJP', // <-- FIX: Added required parameter
                    ),
                  ),
                );
              },
            ),

            // --- Navigation Item: Performa (Access Control for Normal Users) ---
            _NavBarItem(
              icon: Icons.analytics_outlined,
              label: 'Performa',
              onTap: () {
                if (!isNormalUser) { // Only normal users can access
                  _showAccessDeniedDialog(context);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PerformaPage(userId: userId),
                  ),
                );
              },
            ),

            // --- Navigation Item: Akun (Accessible by All) ---
            _NavBarItem(
              icon: Icons.account_circle_outlined,
              label: 'Akun',
              onTap: () {
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
                 _showLogoutConfirmationDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// --- Reusable Bottom Navigation Bar Item Widget (Unchanged) ---
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
    final Color iconColor = Colors.redAccent;
    final Color textColor = Colors.black87;
    final Color splashColor = Colors.red.withOpacity(0.1);
    final Color highlightColor = Colors.red.withOpacity(0.05);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: splashColor,
        highlightColor: highlightColor,
        // tooltip: label, // Optional: Add tooltip
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: iconColor,
                size: 26,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor,
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

// --- Reminder: Ensure Laporan_Penjualan.dart defines the LaporanPenjualan widget ---
// --- with a constructor like:                                                  ---
/*
class LaporanPenjualan extends StatelessWidget {
  final String username;
  final int userId;
  final String outletType; // Make sure this exists and is required

  const LaporanPenjualan({
    Key? key,
    required this.username,
    required this.userId,
    required this.outletType, // Declared as required
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ... Your page implementation ...
    return Scaffold(
      appBar: AppBar(title: Text('Laporan Penjualan ($outletType)')),
      body: Center(child: Text('Data Penjualan for User $userId ($username)')),
    );
  }
}
*/