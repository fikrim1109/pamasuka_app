import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import untuk SystemUiOverlayStyle jika diperlukan
import 'package:pamasuka/rumah_page.dart'; // Pastikan path import benar
import 'home_page.dart'; // Pastikan path import benar
import 'login_page.dart'; // Pastikan path import benar

// --- Definisikan ID Super User ---
const int superUserId = 785;
// --- ---

class MenuPage extends StatelessWidget {
  final String username;
  final int userId;

  const MenuPage({Key? key, required this.username, required this.userId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Tentukan judul berdasarkan tipe user (opsional, tapi bisa menambah kejelasan)
    // String pageTitle = userId == superUserId ? 'Admin Dashboard' : 'Samalonian APP';

    return Scaffold(
      appBar: AppBar(
        // title: Text(pageTitle, ...), // Jika ingin judul dinamis
        title: const Text(
          'Samalonian APP',
          style: TextStyle(
            color: Colors.white, // Warna teks AppBar jadi putih
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.redAccent, // Warna background AppBar disamakan
        elevation: 2,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        automaticallyImplyLeading: false, // Sembunyikan tombol back default jika tidak diperlukan
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
                'images/Samalonian APP.png', // Pastikan path gambar benar
                height: 180,
                fit: BoxFit.contain,
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

class BottomNavBar extends StatelessWidget {
  final String username;
  final int userId;

  const BottomNavBar({Key? key, required this.username, required this.userId})
      : super(key: key);

  // --- Fungsi untuk menampilkan dialog akses ditolak ---
  void _showAccessDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row( // Menggunakan Row untuk ikon dan teks
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red, size: 28), // Ikon X merah
            SizedBox(width: 10),
            Text('Akses Ditolak'),
          ],
        ),
        content: const Text('Anda tidak memiliki izin untuk mengakses halaman ini.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Tutup dialog
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  // --- ---

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // --- Item Outlet PJP (HomePage) ---
          _NavBarItem(
            icon: Icons.store_mall_directory_outlined,
            label: 'Outlet PJP',
            onTap: () {
              // Logika Akses: Hanya user biasa (bukan super user) yang bisa akses
              if (userId != superUserId) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomePage(username: username, userId: userId),
                  ),
                );
              } else {
                // Tampilkan alert akses ditolak untuk super user
                _showAccessDeniedDialog(context);
              }
            },
          ),
          // --- Item Outlet Non PJP (RumahPage) ---
          _NavBarItem(
            icon: Icons.home_work_outlined,
            label: 'Outlet Non PJP',
            onTap: () {
              // Logika Akses: Hanya super user yang bisa akses
              if (userId == superUserId) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RumahPage(username: username, userId: userId),
                  ),
                );
              } else {
                // Tampilkan alert akses ditolak untuk user biasa
                _showAccessDeniedDialog(context);
              }
            },
          ),
          // --- Item Logout ---
          _NavBarItem(
            icon: Icons.logout,
            label: 'Logout',
            onTap: () {
              // Logout bisa diakses semua user
              showDialog(
                context: context,
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
                        Navigator.pop(context); // Tutup dialog
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

// Widget _NavBarItem tidak perlu diubah, hanya menerima properti
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
          padding: const EdgeInsets.symmetric(vertical: 10),
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